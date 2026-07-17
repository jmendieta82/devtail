# Hardening v1 + os_log — Design

Date: 2026-07-17
Branch: `feat/hardening-oslog`
Status: scope approved by Javier; design ready for implementation.

## Problem

1. **The staged teardown never completes at app quit.** `SwiftTermSession.terminate()`
   sends `killpg(pid, SIGTERM)` and schedules `killpg(pid, SIGKILL)` via
   `DispatchQueue.main.asyncAfter(+3s)` (SwiftTermEngine.swift:66-76). At quit,
   `applicationWillTerminate` (DevtailApp.swift:122-124) calls the synchronous
   `holder.shutdownAll()` and returns immediately — the app exits before the +3s
   block runs. Any child that ignores SIGTERM (watch-mode dev servers under load,
   stuck processes) is orphaned.
2. **The kill policy is hard-coded and untestable.** Real `killpg` calls and a real
   `DispatchQueue` deadline live inline in `SwiftTermSession`; return values are
   ignored. Existing mocks (`MockTerminalSession`) only count `terminate()` calls —
   the SIGTERM → grace → SIGKILL sequence has zero test coverage.
3. **Failures are swallowed silently app-wide.** Exactly one `Logger` exists
   (PersistenceController.swift:12). Migration failures (`try?` at
   DevtailApp.swift:27), git reader failures/timeouts, Claude introspection `try?`
   sites, unreadable search directories, .env save errors, all 13 `ProjectStore`
   catch blocks, and stack-detector skips leave no trace for diagnosis.

## Goals

- The SIGTERM → grace → SIGKILL escalation actually fires on the app-quit path.
- The staged-kill policy is an isolated, deterministic, fully tested unit.
- Every silent-swallow seam emits a structured `Logger` line, local-only
  (unified logging; consistent with the zero-telemetry rule).

## Non-goals

- No own `waitpid` reaping — SwiftTerm owns the child and reports exits via
  `processTerminated`; after SIGKILL the kernel reparents and reaps.
- No SIGINT/SIGHUP handling; no change to the 3-second runtime grace.
- No log persistence, export, or in-app log viewer.

## Design

### Task 1 — Extract the staged-kill policy (`ProcessTeardown`)

New file `Devtail/Features/Workspace/Services/ProcessTeardown.swift`:

```swift
/// SIGTERM -> grace -> SIGKILL against a process group, with injectable
/// signal delivery and scheduling so the sequence is unit-testable.
struct ProcessTeardown {
    var signal: (pid_t, Int32) -> Int32          // production: killpg
    var schedule: (TimeInterval, @escaping @MainActor () -> Void) -> Void
    static let grace: TimeInterval = 3

    func terminate(group pid: pid_t, isExited: @escaping () -> Bool)
}
```

- `terminate` sends SIGTERM, logs a failed `killpg` (non-zero return + errno),
  then schedules the SIGKILL after `grace`; the scheduled block re-checks
  `isExited()` and skips the SIGKILL if the process already left.
- `SwiftTermSession.terminate()` shrinks to: cleanup images, guard `!exited`,
  guard `pid > 0`, delegate to `ProcessTeardown` with `isExited: { self.exited }`.
  Behavior at runtime is byte-identical to today (same signals, same 3s grace,
  same main-queue scheduling) — this task is extraction, not behavior change.
- The default (production) instance uses real `killpg` and
  `DispatchQueue.main.asyncAfter`; tests inject a signal spy and a captured
  scheduler they fire manually.

### Task 2 — Close the quit gap (`applicationShouldTerminate`)

Replace the `applicationWillTerminate` teardown with a deferred quit:

```swift
func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard let holder = AppDelegate.workspaceHolder, holder.hasLiveSessions else {
        return .terminateNow
    }
    holder.shutdownAll(deadline: Self.quitGrace) {
        sender.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
}
```

- `WorkspaceSessionsHolder` gains `shutdownAll(deadline:completion:)`:
  1. Sends `terminate()` to every live session (SIGTERM wave, exactly today's
     `shutdownAll` semantics) and closes non-process resources (search tasks,
     git/claude tasks) immediately.
  2. Tracks outstanding sessions through the existing `onExit` callbacks; when
     the last one exits, completes early.
  3. On deadline (default `quitGrace = 2.0s`, injectable scheduler shared with
     `ProcessTeardown`), force-kills stragglers via SIGKILL and completes.
     SIGKILL cannot be ignored, so completing right after delivery is safe —
     no wait-for-reap needed.
- Why `.terminateLater` and not a synchronous bounded wait: SwiftTerm delivers
  `processTerminated` on the main run loop. Blocking the main thread would
  freeze the very callbacks that tell us sessions exited, turning every quit
  into a full-grace stall. `.terminateLater` keeps the run loop alive, so a
  fast SIGTERM-compliant exit finishes the quit in milliseconds.
- The existing parameterless `shutdownAll()` remains for non-quit callers and
  becomes the SIGTERM wave step of the deadline variant.
- `applicationWillTerminate` stays as a last-resort no-op removal (the deferred
  path already ran) — it will simply no longer be the teardown owner.

### Task 3 — os_log adoption

New file `Devtail/Core/Logging/Log.swift` following the PersistenceController
precedent (subsystem `com.jamodev.Devtail`, `privacy: .public`):

```swift
enum Log {
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let migration = Logger(subsystem: subsystem, category: "migration")
    static let git       = Logger(subsystem: subsystem, category: "git")
    static let claude    = Logger(subsystem: subsystem, category: "claude")
    static let search    = Logger(subsystem: subsystem, category: "search")
    static let files     = Logger(subsystem: subsystem, category: "files")
    static let store     = Logger(subsystem: subsystem, category: "store")
}
```

PersistenceController keeps its own local `Logger` (already shipped; category
`persistence` stays as-is).

Seam coverage and levels:

| Seam | Category | Level |
| --- | --- | --- |
| `LegacyClaudePaneMigration.run` failure (DevtailApp.swift:27 `try?`) | migration | error |
| `ProcessTeardown` failed `killpg`, SIGKILL escalation fired | lifecycle | error / info |
| Quit path: deferred quit started, early completion, deadline force-kill | lifecycle | info |
| `ProcessSupervisor` start/stop/restart/close transitions | lifecycle | debug |
| `GitStatusReader` launch failure, non-zero exit, timeout | git | error |
| `ClaudeProjectIntrospector` top-level read failure (not per-field `try?`) | claude | error |
| `FileSearchWalker` unreadable directory skip | search | debug |
| .env save failures (WorkspaceSessionsHolder, EnvFileEditorView) | files | error |
| `FileTreeStore` listing errors (already UI-surfaced) | files | error |
| `ProjectStore` catch blocks (13 sites, `lastError` assignments) | store | error |
| `StackDetectorRegistry` detector skip | store | debug |

Rules: `.fault` reserved for invariant breaks (persistence precedent), `.error`
for real failures a user might ask about, `.debug` for expected skips. No
logging inside per-entry hot loops (the walker logs per skipped directory, not
per file).

## Test plan

- `ProcessTeardownTests`: signal spy + manual scheduler — asserts SIGTERM
  first, SIGKILL after grace, SIGKILL skipped when `isExited` flips, non-zero
  `killpg` handled.
- `WorkspaceSessionsHolderTests` additions: `shutdownAll(deadline:)` with
  `MockTerminalEngine` — early completion when all sessions exit before the
  deadline; force-kill + completion at deadline when one session never exits;
  completion called exactly once.
- AppDelegate quit logic stays thin enough to not need its own harness; the
  decision logic lives in the holder.
- Logging calls are not asserted (no seam worth building for it); the suite
  guards behavior, `log stream` guards observability manually.

## Verification

- Full suite green (baseline 538 tests).
- Manual checkpoint: open a workspace running a SIGTERM-ignoring child, quit
  Devtail, verify via `ps` that the process group is gone within ~2s and via
  `log stream --predicate 'subsystem == "com.jamodev.Devtail"'` that the
  escalation was logged.
