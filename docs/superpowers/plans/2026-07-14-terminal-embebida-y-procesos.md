# Embedded Terminal + Managed Processes v1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the AppleScript→Ghostty launch path with a per-project workspace window hosting an embedded SwiftTerm terminal plus Estación-style managed dev-server processes (start/stop/restart with ANSI logs).

**Architecture:** New `Features/Workspace/` module. A `TerminalEngine` protocol abstracts the emulator (`SwiftTermEngine` v1); every managed process runs in its own read-only PTY session ("todo es PTY" — logs are terminals). `ProcessSupervisor` (@Observable) owns process lifecycle with `$SHELL -ilc` spawn and process-group kill. A `WorkspaceSessionsHolder` retains per-project sessions OUTSIDE SwiftUI so terminal NSViews never die on tab switches. Spec: `docs/superpowers/specs/2026-07-14-terminal-embebida-y-procesos-design.md`.

**Tech Stack:** SwiftUI + AppKit bridge (`NSViewRepresentable`), SwiftData (existing models untouched), SwiftTerm (SPM — first external dependency), Swift Testing (`@Test`/`#expect`), Xcode project `Devtail.xcodeproj` (objectVersion 77).

## Global Constraints

- Swift 6 concurrency defaults are ON: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. New types are implicitly MainActor unless annotated otherwise.
- State pattern: `@Observable` classes only — never `ObservableObject`/`@Published`.
- DI pattern: protocol + concrete impl + mock in tests (matches `WorkspaceLauncherProtocol` precedent).
- Tests: Swift Testing (`import Testing`, `@Test`, `#expect`), files under `DevtailTests/Features/Workspace/`.
- UI copy in **English** (project convention: "New Project", "Settings"). Comments in English.
- Conventional commits, NO AI attribution.
- Build/test command: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet` (run from repo root `/Volumes/Datos/Frelancer/DEVTAIL/Devtail`). Focused run: append `-only-testing:DevtailTests/<TestClassName>`.
- Process spawn contract (from spec, non-negotiable): commands run via `$SHELL -ilc "<command>"`; the PTY child is a process-group leader (forkpty does `setsid`); stop = `killpg(SIGTERM)` → ~3s grace → `killpg(SIGKILL)`; restart produces a FRESH session (clean log).
- Terminal NSViews are retained in the holder/supervisor and hidden — never conditionally removed by SwiftUI (`ZStack` + `.opacity`/`hidden`, no `if/else`).
- SwiftTerm API note: anchor names (`LocalProcessTerminalView`, `LocalProcess.shellPid`, delegate methods) are correct for SwiftTerm ~1.2 but MAY drift slightly by version. If a symbol differs, adapt the adapter (`SwiftTermEngine.swift` only) keeping the protocol contract intact — the contract is pinned by `MockTerminalEngine` tests, not by SwiftTerm.

---

### Task 1: Project plumbing — drop App Sandbox, add SwiftTerm SPM

**Files:**
- Modify: `Devtail/Devtail.entitlements`
- Modify: `Devtail.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: nothing.
- Produces: `import SwiftTerm` compiles for target `Devtail`; app runs unsandboxed.

- [ ] **Step 1: Rewrite the entitlements file**

Replace the full contents of `Devtail/Devtail.entitlements` with (removes `app-sandbox`, `automation.apple-events`, and the Ghostty temporary exception; keeps the file-access keys — harmless, cleaned up in a future pass per spec):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 2: Add the SwiftTerm package reference to the pbxproj**

Edit `Devtail.xcodeproj/project.pbxproj` (objectVersion 77, plist-text format). Three insertions — use these exact 24-hex IDs (they only need to be unique within the file):

1. Add a `XCRemoteSwiftPackageReference` section (place it alphabetically among the top-level sections, e.g. right before `/* Begin XCSwiftPackageProductDependency section */` if present, otherwise before the closing `rootObject` line — follow the `/* Begin X section */ ... /* End X section */` comment convention):

```
/* Begin XCRemoteSwiftPackageReference section */
		DE5717E0000000000000A001 /* XCRemoteSwiftPackageReference "SwiftTerm" */ = {
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/migueldeicaza/SwiftTerm";
			requirement = {
				kind = upToNextMajorVersion;
				minimumVersion = 1.2.0;
			};
		};
/* End XCRemoteSwiftPackageReference section */
```

2. Add a `XCSwiftPackageProductDependency` section:

```
/* Begin XCSwiftPackageProductDependency section */
		DE5717E1000000000000A002 /* SwiftTerm */ = {
			isa = XCSwiftPackageProductDependency;
			package = DE5717E0000000000000A001 /* XCRemoteSwiftPackageReference "SwiftTerm" */;
			productName = SwiftTerm;
		};
/* End XCSwiftPackageProductDependency section */
```

3. Wire both into the project and app target:
   - In the `PBXProject` object (the one with `isa = PBXProject`), add to (or create) its `packageReferences` array: `DE5717E0000000000000A001 /* XCRemoteSwiftPackageReference "SwiftTerm" */,`
   - In the `PBXNativeTarget` for `Devtail` (the app target, NOT `DevtailTests`), add to (or create) its `packageProductDependencies` array: `DE5717E1000000000000A002 /* SwiftTerm */,`

(objectVersion 77 targets use `packageProductDependencies` directly — no `PBXBuildFile`/Frameworks-phase entry is needed; if the build later complains about a missing product, add the classic `PBXBuildFile` + Frameworks-phase pair as fallback.)

- [ ] **Step 3: Resolve and build**

Run:
```bash
xcodebuild -resolvePackageDependencies -project Devtail.xcodeproj -scheme Devtail
xcodebuild build -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet
```
Expected: package graph resolves SwiftTerm; build succeeds with no errors.

- [ ] **Step 4: Run the existing suite (regression gate)**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet`
Expected: all existing tests pass (sandbox removal must not break anything).

- [ ] **Step 5: Commit**

```bash
git add Devtail/Devtail.entitlements Devtail.xcodeproj/project.pbxproj
git commit -m "feat(workspace): drop app sandbox and add SwiftTerm dependency"
```

---

### Task 2: `TerminalEngine` protocol + pure shell invocation builder

**Files:**
- Create: `Devtail/Features/Workspace/Services/TerminalEngine.swift`
- Create: `Devtail/Features/Workspace/Services/ShellCommand.swift`
- Test: `DevtailTests/Features/Workspace/ShellCommandTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces (used by Tasks 3–6):
  - `struct TerminalSessionConfig { let command: String?; let cwd: URL; let readOnly: Bool }`
  - `protocol TerminalSession: AnyObject { var view: NSView { get }; var onExit: ((Int32?) -> Void)? { get set }; func start(); func terminate(); func writeToStdin(_ text: String) }`
  - `protocol TerminalEngine: AnyObject { func makeSession(_ config: TerminalSessionConfig) -> TerminalSession }`
  - `enum ShellCommand { static func userShell(environment:) -> String; static func loginShellInvocation(command:shell:) -> [String] }`

- [ ] **Step 1: Write the failing tests**

Create `DevtailTests/Features/Workspace/ShellCommandTests.swift`:

```swift
import Testing
@testable import Devtail

struct ShellCommandTests {
    @Test func userShellReadsSHELLFromEnvironment() {
        #expect(ShellCommand.userShell(environment: ["SHELL": "/opt/homebrew/bin/fish"]) == "/opt/homebrew/bin/fish")
    }

    @Test func userShellFallsBackToZsh() {
        #expect(ShellCommand.userShell(environment: [:]) == "/bin/zsh")
    }

    @Test func loginShellInvocationWrapsCommandWithILC() {
        let inv = ShellCommand.loginShellInvocation(command: "npm run dev", shell: "/bin/zsh")
        #expect(inv == ["/bin/zsh", "-ilc", "npm run dev"])
    }

    @Test func loginShellInvocationWithoutCommandIsInteractiveLogin() {
        #expect(ShellCommand.loginShellInvocation(command: nil, shell: "/bin/zsh") == ["/bin/zsh", "-il"])
        #expect(ShellCommand.loginShellInvocation(command: "  ", shell: "/bin/zsh") == ["/bin/zsh", "-il"])
    }

    @Test func commandWithQuotesPassesThroughUntouched() {
        // Args go to execv as an array — no shell re-quoting of our own.
        let inv = ShellCommand.loginShellInvocation(command: #"echo "hola mundo""#, shell: "/bin/zsh")
        #expect(inv[2] == #"echo "hola mundo""#)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet -only-testing:DevtailTests/ShellCommandTests`
Expected: FAIL — `ShellCommand` not found (compile error counts as RED).

- [ ] **Step 3: Implement**

Create `Devtail/Features/Workspace/Services/ShellCommand.swift`:

```swift
//
//  ShellCommand.swift
//  Devtail
//
//  Pure helpers for building the PTY spawn invocation. Commands run through
//  the user's interactive LOGIN shell so PATH additions from ~/.zshrc
//  (Homebrew, nvm, zoxide) are present even when the app is opened from
//  Finder — a plain `-l` shell does not source ~/.zshrc.
//

import Foundation

enum ShellCommand {
    /// The user's shell, from $SHELL, defaulting to zsh (macOS default).
    static func userShell(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        let shell = environment["SHELL"] ?? ""
        return shell.isEmpty ? "/bin/zsh" : shell
    }

    /// execv-style invocation: `[shell, "-ilc", command]`, or `[shell, "-il"]`
    /// for a plain interactive session. Args are passed as an array — the
    /// shell receives `command` verbatim, no extra quoting layer.
    static func loginShellInvocation(command: String?, shell: String) -> [String] {
        let trimmed = command?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return [shell, "-il"] }
        return [shell, "-ilc", trimmed]
    }
}
```

Create `Devtail/Features/Workspace/Services/TerminalEngine.swift`:

```swift
//
//  TerminalEngine.swift
//  Devtail
//
//  Emulator abstraction. Consumers (interactive terminal, ProcessSupervisor)
//  talk to these protocols only — never to SwiftTerm directly — so the engine
//  can be mocked in tests and swapped (libghostty) without touching callers.
//

import AppKit

struct TerminalSessionConfig {
    /// Command to run via the login shell; nil/blank = plain interactive shell.
    let command: String?
    /// Working directory for the session.
    let cwd: URL
    /// Read-only sessions render output but swallow keyboard input (process logs).
    let readOnly: Bool
}

@MainActor
protocol TerminalSession: AnyObject {
    /// The emulator's NSView. Retained by the owner; SwiftUI only shows/hides it.
    var view: NSView { get }
    /// Fired once when the session's process exits (code nil if unknown).
    var onExit: ((Int32?) -> Void)? { get set }
    /// Spawn the PTY child (process-group leader) and start emulation.
    func start()
    /// killpg(SIGTERM) → grace → killpg(SIGKILL). Idempotent.
    func terminate()
    /// Forward text to the session's stdin (interactive sessions).
    func writeToStdin(_ text: String)
}

@MainActor
protocol TerminalEngine: AnyObject {
    func makeSession(_ config: TerminalSessionConfig) -> TerminalSession
}
```

- [ ] **Step 4: Run to verify pass**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet -only-testing:DevtailTests/ShellCommandTests`
Expected: PASS — 5 tests.

- [ ] **Step 5: Commit**

```bash
git add Devtail/Features/Workspace/Services/ShellCommand.swift Devtail/Features/Workspace/Services/TerminalEngine.swift DevtailTests/Features/Workspace/ShellCommandTests.swift
git commit -m "feat(workspace): TerminalEngine protocol and login-shell invocation builder"
```

---

### Task 3: `SwiftTermEngine` — the SwiftTerm adapter

**Files:**
- Create: `Devtail/Features/Workspace/Services/SwiftTermEngine.swift`

**Interfaces:**
- Consumes: Task 2's protocols + `ShellCommand`.
- Produces: `final class SwiftTermEngine: TerminalEngine` (used by Task 5/6 wiring).

No unit tests for this adapter (it is the thin, real-PTY boundary — pinned by the manual checkpoint in Task 7; the contract is tested via `MockTerminalEngine` in Task 4). Gate: it compiles and the suite stays green.

- [ ] **Step 1: Implement the adapter**

Create `Devtail/Features/Workspace/Services/SwiftTermEngine.swift`:

```swift
//
//  SwiftTermEngine.swift
//  Devtail
//
//  TerminalEngine adapter over SwiftTerm. Kept deliberately thin: every
//  behavioral decision (spawn shape, kill semantics) lives here so a future
//  libghostty engine replaces ONLY this file.
//
//  Kill semantics: forkpty's child calls setsid, so the shell is a
//  process-group leader and killpg(shellPid, …) reaches the whole tree —
//  `nest --watch` children included. SIGTERM first, SIGKILL after a 3s grace.
//

import AppKit
import SwiftTerm

final class SwiftTermEngine: TerminalEngine {
    func makeSession(_ config: TerminalSessionConfig) -> TerminalSession {
        SwiftTermSession(config: config)
    }
}

final class SwiftTermSession: NSObject, TerminalSession, LocalProcessTerminalViewDelegate {
    private let config: TerminalSessionConfig
    private let terminalView: LocalProcessTerminalView
    private var exited = false

    var onExit: ((Int32?) -> Void)?
    var view: NSView { terminalView }

    init(config: TerminalSessionConfig) {
        self.config = config
        self.terminalView = config.readOnly
            ? ReadOnlyLocalProcessTerminalView(frame: .zero)
            : LocalProcessTerminalView(frame: .zero)
        super.init()
        terminalView.processDelegate = self
    }

    func start() {
        let shell = ShellCommand.userShell()
        let invocation = ShellCommand.loginShellInvocation(command: config.command, shell: shell)
        FileManager.default.changeCurrentDirectoryPath(config.cwd.path)
        terminalView.startProcess(
            executable: invocation[0],
            args: Array(invocation.dropFirst()),
            environment: Terminal.getEnvironmentVariables(termName: "xterm-256color"),
            execName: nil
        )
    }

    func terminate() {
        guard !exited else { return }
        let pid = terminalView.process.shellPid
        guard pid > 0 else { return }
        killpg(pid, SIGTERM)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, !self.exited else { return }
            killpg(pid, SIGKILL)
        }
    }

    func writeToStdin(_ text: String) {
        terminalView.send(txt: text)
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        exited = true
        onExit?(exitCode)
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}

/// A terminal view that renders output but swallows all keyboard input —
/// process logs are observable, not typable.
final class ReadOnlyLocalProcessTerminalView: LocalProcessTerminalView {
    override func keyDown(with event: NSEvent) { /* read-only: swallow */ }
}
```

Implementation notes for the engineer:
- `FileManager.changeCurrentDirectoryPath` before `startProcess` is how SwiftTerm's local process inherits a cwd (its `startProcess` has no cwd parameter in 1.2). It changes the APP's cwd momentarily — acceptable for v1 (spawns are user-initiated, serial on MainActor). If the installed SwiftTerm version exposes a `currentDirectory`/cwd parameter, use it instead and delete the `changeCurrentDirectoryPath` line.
- If `terminalView.process.shellPid` is not public in the resolved SwiftTerm version, check for `terminalView.shellPid` or keep a reference from `startProcess`'s return; adapt inside this file only.

- [ ] **Step 2: Build + full suite**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet`
Expected: builds clean, all tests pass.

- [ ] **Step 3: Commit**

```bash
git add Devtail/Features/Workspace/Services/SwiftTermEngine.swift
git commit -m "feat(workspace): SwiftTerm engine adapter with process-group kill"
```

---

### Task 4: `ProcessSupervisor` + `ManagedProcess` (TDD core)

**Files:**
- Create: `Devtail/Features/Workspace/Models/ManagedProcess.swift`
- Create: `Devtail/Features/Workspace/Services/ProcessSupervisor.swift`
- Test: `DevtailTests/Features/Workspace/MockTerminalEngine.swift`
- Test: `DevtailTests/Features/Workspace/ProcessSupervisorTests.swift`

**Interfaces:**
- Consumes: Task 2 protocols; existing `WorkspacePane` (`label`, `relativeCwd`, `command`, `order`, `isFrontend`, `localhostUrl`, `id`); existing `BrowserLauncherProtocol` (`func open(urlString: String)` in `Devtail/Core/Shell/BrowserLauncher.swift` — verify exact signature there and match it).
- Produces (used by Tasks 5–6):
  - `enum ProcessRunState: Equatable { case stopped, starting, running, exited(Int32?) }`
  - `final class ManagedProcess: Identifiable { let id: UUID; let name: String; let command: String; let cwd: URL; let isFrontend: Bool; let localhostUrl: String?; var state: ProcessRunState; var session: TerminalSession? }`
  - `final class ProcessSupervisor { init(engine: TerminalEngine, browserLauncher: BrowserLauncherProtocol); var processes: [ManagedProcess]; func configure(panes: [WorkspacePane], root: URL); func startAll(); func start(_:); func stop(_:); func restart(_:); func shutdownAll() }`

- [ ] **Step 1: Write the mock engine**

Create `DevtailTests/Features/Workspace/MockTerminalEngine.swift`:

```swift
import AppKit
@testable import Devtail

final class MockTerminalSession: TerminalSession {
    let view = NSView()
    var onExit: ((Int32?) -> Void)?
    private(set) var startCount = 0
    private(set) var terminateCount = 0
    private(set) var written: [String] = []

    func start() { startCount += 1 }
    func terminate() { terminateCount += 1 }
    func writeToStdin(_ text: String) { written.append(text) }
    /// Test hook: simulate the PTY child dying.
    func simulateExit(code: Int32?) { onExit?(code) }
}

final class MockTerminalEngine: TerminalEngine {
    private(set) var sessions: [MockTerminalSession] = []
    private(set) var configs: [TerminalSessionConfig] = []

    func makeSession(_ config: TerminalSessionConfig) -> TerminalSession {
        let session = MockTerminalSession()
        sessions.append(session)
        configs.append(config)
        return session
    }
}

final class MockBrowserLauncher: BrowserLauncherProtocol {
    private(set) var opened: [String] = []
    func open(urlString: String) { opened.append(urlString) }
}
```

(If `BrowserLauncherProtocol`'s method signature differs in `Devtail/Core/Shell/BrowserLauncher.swift`, mirror the real one here and in the supervisor.)

- [ ] **Step 2: Write the failing tests**

Create `DevtailTests/Features/Workspace/ProcessSupervisorTests.swift`:

```swift
import Foundation
import Testing
@testable import Devtail

@MainActor
struct ProcessSupervisorTests {
    private func makeSUT() -> (ProcessSupervisor, MockTerminalEngine, MockBrowserLauncher) {
        let engine = MockTerminalEngine()
        let browser = MockBrowserLauncher()
        return (ProcessSupervisor(engine: engine, browserLauncher: browser), engine, browser)
    }

    private func pane(_ label: String, cwd: String = ".", command: String = "npm run dev",
                      order: Int, slot: Int = -1, frontend: Bool = false, url: String? = nil) -> WorkspacePane {
        WorkspacePane(label: label, relativeCwd: cwd, command: command, order: order,
                      layoutSlot: slot, isFrontend: frontend, localhostUrl: url, project: nil)
    }

    @Test func configureMapsPanesSortedByOrderIgnoringLayoutSlot() {
        let (sut, _, _) = makeSUT()
        let root = URL(fileURLWithPath: "/tmp/proj", isDirectory: true)
        // Legacy project shape: layoutSlot values present — must be irrelevant.
        sut.configure(panes: [pane("front", cwd: "web", order: 1, slot: 3),
                              pane("back", cwd: "api", order: 0, slot: 0)], root: root)
        #expect(sut.processes.map(\.name) == ["back", "front"])
        #expect(sut.processes[0].cwd.path == "/tmp/proj/api")
        #expect(sut.processes.allSatisfy { $0.state == .stopped })
    }

    @Test func startSpawnsReadOnlySessionAndRuns() {
        let (sut, engine, _) = makeSUT()
        sut.configure(panes: [pane("back", cwd: "api", order: 0)], root: URL(fileURLWithPath: "/tmp/p"))
        sut.start(sut.processes[0])
        #expect(sut.processes[0].state == .running)
        #expect(engine.sessions.count == 1)
        #expect(engine.sessions[0].startCount == 1)
        #expect(engine.configs[0].readOnly)
        #expect(engine.configs[0].command == "npm run dev")
    }

    @Test func startAllStartsEveryProcessAndOpensFrontendBrowserOnce() {
        let (sut, engine, browser) = makeSUT()
        sut.configure(panes: [pane("back", order: 0),
                              pane("front", order: 1, frontend: true, url: "http://localhost:4200")],
                      root: URL(fileURLWithPath: "/tmp/p"))
        sut.startAll()
        #expect(engine.sessions.count == 2)
        #expect(browser.opened == ["http://localhost:4200"])
    }

    @Test func exitCallbackMovesStateToExitedWithCode() {
        let (sut, engine, _) = makeSUT()
        sut.configure(panes: [pane("back", order: 0)], root: URL(fileURLWithPath: "/tmp/p"))
        sut.start(sut.processes[0])
        engine.sessions[0].simulateExit(code: 137)
        #expect(sut.processes[0].state == .exited(137))
    }

    @Test func stopTerminatesSessionAndMarksStopped() {
        let (sut, engine, _) = makeSUT()
        sut.configure(panes: [pane("back", order: 0)], root: URL(fileURLWithPath: "/tmp/p"))
        sut.start(sut.processes[0])
        sut.stop(sut.processes[0])
        #expect(engine.sessions[0].terminateCount == 1)
        #expect(sut.processes[0].state == .stopped)
    }

    @Test func restartCreatesFreshSessionSoLogIsClean() {
        let (sut, engine, _) = makeSUT()
        sut.configure(panes: [pane("back", order: 0)], root: URL(fileURLWithPath: "/tmp/p"))
        sut.start(sut.processes[0])
        sut.restart(sut.processes[0])
        // Old session terminated, NEW session spawned — fresh scrollback by construction.
        #expect(engine.sessions.count == 2)
        #expect(engine.sessions[0].terminateCount == 1)
        #expect(engine.sessions[1].startCount == 1)
        #expect(sut.processes[0].session === engine.sessions[1])
        #expect(sut.processes[0].state == .running)
    }

    @Test func shutdownAllTerminatesEveryRunningSession() {
        let (sut, engine, _) = makeSUT()
        sut.configure(panes: [pane("a", order: 0), pane("b", order: 1)], root: URL(fileURLWithPath: "/tmp/p"))
        sut.startAll()
        sut.shutdownAll()
        #expect(engine.sessions.allSatisfy { $0.terminateCount == 1 })
        #expect(sut.processes.allSatisfy { $0.state == .stopped })
    }

    @Test func exitAfterStopDoesNotResurrectExitedState() {
        let (sut, engine, _) = makeSUT()
        sut.configure(panes: [pane("back", order: 0)], root: URL(fileURLWithPath: "/tmp/p"))
        sut.start(sut.processes[0])
        sut.stop(sut.processes[0])
        // killpg → child dies → PTY reports exit AFTER we already marked stopped.
        engine.sessions[0].simulateExit(code: 0)
        #expect(sut.processes[0].state == .stopped)
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet -only-testing:DevtailTests/ProcessSupervisorTests`
Expected: FAIL — `ProcessSupervisor`/`ManagedProcess` not found.

- [ ] **Step 4: Implement**

Create `Devtail/Features/Workspace/Models/ManagedProcess.swift`:

```swift
//
//  ManagedProcess.swift
//  Devtail
//
//  Runtime state of one managed dev-server process. Built FROM a
//  WorkspacePane (the persisted definition) — panes are reinterpreted as
//  process definitions in v1; layoutSlot and friends are ignored.
//  Not a SwiftData model: run state is ephemeral by design.
//

import Foundation

enum ProcessRunState: Equatable {
    case stopped
    case starting
    case running
    case exited(Int32?)
}

@Observable
final class ManagedProcess: Identifiable {
    let id: UUID
    let name: String
    let command: String
    let cwd: URL
    let isFrontend: Bool
    let localhostUrl: String?

    var state: ProcessRunState = .stopped
    /// The live PTY session (also the log view's source). Replaced on restart.
    var session: TerminalSession?

    init(pane: WorkspacePane, root: URL) {
        self.id = pane.id
        self.name = pane.label
        self.command = pane.command
        self.isFrontend = pane.isFrontend
        self.localhostUrl = pane.localhostUrl
        let folder = pane.relativeCwd.trimmingCharacters(in: .whitespacesAndNewlines)
        self.cwd = (folder.isEmpty || folder == ".")
            ? root
            : root.appendingPathComponent(
                folder.hasPrefix("./") ? String(folder.dropFirst(2)) : folder,
                isDirectory: true
            )
    }
}
```

Create `Devtail/Features/Workspace/Services/ProcessSupervisor.swift`:

```swift
//
//  ProcessSupervisor.swift
//  Devtail
//
//  Owns the lifecycle of a workspace's managed processes. Every process runs
//  in its own read-only PTY session ("everything is a PTY"): ANSI-colored,
//  scrollback-capable logs for free, and dev servers see a real TTY so they
//  don't buffer. Sessions are retained here — the UI only shows/hides views.
//

import Foundation

@Observable
final class ProcessSupervisor {
    private let engine: TerminalEngine
    private let browserLauncher: BrowserLauncherProtocol

    private(set) var processes: [ManagedProcess] = []

    init(engine: TerminalEngine, browserLauncher: BrowserLauncherProtocol) {
        self.engine = engine
        self.browserLauncher = browserLauncher
    }

    /// Build the process list from the project's panes (persisted definitions),
    /// sorted by `order`. `layoutSlot` and the old layout topology are ignored —
    /// this is the v1 migration semantics for legacy projects.
    func configure(panes: [WorkspacePane], root: URL) {
        shutdownAll()
        processes = panes
            .sorted { $0.order < $1.order }
            .map { ManagedProcess(pane: $0, root: root) }
    }

    func startAll() {
        for process in processes { start(process) }
    }

    func start(_ process: ManagedProcess) {
        guard process.state != .running, process.state != .starting else { return }
        process.state = .starting
        let session = engine.makeSession(
            TerminalSessionConfig(command: process.command, cwd: process.cwd, readOnly: true)
        )
        session.onExit = { [weak process] code in
            guard let process, process.state == .running || process.state == .starting else { return }
            process.state = .exited(code)
        }
        process.session = session
        session.start()
        process.state = .running

        if process.isFrontend, let url = process.localhostUrl,
           !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            browserLauncher.open(urlString: url)
        }
    }

    func stop(_ process: ManagedProcess) {
        // Mark stopped FIRST so the PTY's late exit callback can't overwrite
        // an intentional stop with .exited.
        process.state = .stopped
        process.session?.terminate()
    }

    /// Stop + spawn a FRESH session: new PTY, new view, clean scrollback.
    func restart(_ process: ManagedProcess) {
        stop(process)
        process.session = nil
        start(process)
    }

    func shutdownAll() {
        for process in processes { stop(process) }
    }
}
```

- [ ] **Step 5: Run to verify pass**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet -only-testing:DevtailTests/ProcessSupervisorTests`
Expected: PASS — 8 tests.

- [ ] **Step 6: Full suite + commit**

Run the full suite, then:
```bash
git add Devtail/Features/Workspace/Models/ManagedProcess.swift Devtail/Features/Workspace/Services/ProcessSupervisor.swift DevtailTests/Features/Workspace/MockTerminalEngine.swift DevtailTests/Features/Workspace/ProcessSupervisorTests.swift
git commit -m "feat(workspace): ProcessSupervisor with PTY-per-process lifecycle"
```

---

### Task 5: Workspace window — holder, root view, terminal retention, tabs

**Files:**
- Create: `Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift`
- Create: `Devtail/Features/Workspace/Views/TerminalHostView.swift`
- Create: `Devtail/Features/Workspace/Views/WorkspaceRootView.swift`
- Create: `Devtail/Features/Workspace/Views/Components/ProcessCardView.swift`
- Modify: `Devtail/App/DevtailApp.swift`
- Test: `DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift`

**Interfaces:**
- Consumes: Tasks 2–4 types; `Project` (`id`, `name`, `directoryPath`, `workspacePanes`); `DevtailTokens`; existing `BrowserLauncher`.
- Produces: `WorkspaceSessionsHolder` with `func openSession(for project: Project) -> WorkspaceSession`, `func close(projectId: UUID)`, `func isOpen(_ projectId: UUID) -> Bool`, `func shutdownAll()`; window id `WindowID.workspace = "devtail.workspace"` opened via `openWindow(id: WindowID.workspace, value: project.id)` (used by Task 6).

- [ ] **Step 1: Write the failing holder tests**

Create `DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift`:

```swift
import Foundation
import Testing
@testable import Devtail

@MainActor
struct WorkspaceSessionsHolderTests {
    private func makeSUT() -> (WorkspaceSessionsHolder, MockTerminalEngine) {
        let engine = MockTerminalEngine()
        let holder = WorkspaceSessionsHolder(engine: engine, browserLauncher: MockBrowserLauncher())
        return (holder, engine)
    }

    private func project(_ name: String) -> Project {
        Project(name: name, directoryPath: "/tmp/\(name)")
    }

    @Test func openSessionSpawnsInteractiveTerminalAtRootAndIsIdempotent() {
        let (holder, engine) = makeSUT()
        let p = project("alpha")
        let s1 = holder.openSession(for: p)
        let s2 = holder.openSession(for: p)
        #expect(s1 === s2)
        // Exactly one interactive (non-readOnly, nil command) session at the root.
        #expect(engine.configs.count { !$0.readOnly } == 1)
        let interactive = engine.configs.first { !$0.readOnly }
        #expect(interactive?.command == nil)
        #expect(interactive?.cwd.path == "/tmp/alpha")
        #expect(holder.isOpen(p.id))
    }

    @Test func closeShutsDownProcessesAndTerminal() {
        let (holder, engine) = makeSUT()
        let p = project("alpha")
        _ = holder.openSession(for: p)
        holder.close(projectId: p.id)
        #expect(!holder.isOpen(p.id))
        #expect(engine.sessions.allSatisfy { $0.terminateCount >= 1 })
    }

    @Test func shutdownAllClosesEveryOpenWorkspace() {
        let (holder, engine) = makeSUT()
        _ = holder.openSession(for: project("a"))
        _ = holder.openSession(for: project("b"))
        holder.shutdownAll()
        #expect(engine.sessions.allSatisfy { $0.terminateCount >= 1 })
    }
}
```

(If `Project`'s initializer requires more arguments, check `Devtail/Features/ContextSwitcher/Models/Project.swift` and use its minimal init — adjust only the test helper, not the assertions.)

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild test ... -only-testing:DevtailTests/WorkspaceSessionsHolderTests`
Expected: FAIL — `WorkspaceSessionsHolder` not found.

- [ ] **Step 3: Implement holder**

Create `Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift`:

```swift
//
//  WorkspaceSessionsHolder.swift
//  Devtail
//
//  App-level owner of live workspace sessions, keyed by project id. Terminal
//  NSViews and PTYs live HERE, outside SwiftUI's view lifecycle: tab switches
//  and window re-renders must never destroy a session (destroying the NSView
//  kills scrollback and the PTY). Views borrow; the holder owns.
//

import Foundation

@Observable
final class WorkspaceSession: Identifiable {
    let projectId: UUID
    let projectName: String
    let root: URL
    let supervisor: ProcessSupervisor
    let interactive: TerminalSession
    /// nil = interactive terminal tab; otherwise a ManagedProcess id.
    var selectedTab: UUID?

    init(projectId: UUID, projectName: String, root: URL,
         supervisor: ProcessSupervisor, interactive: TerminalSession) {
        self.projectId = projectId
        self.projectName = projectName
        self.root = root
        self.supervisor = supervisor
        self.interactive = interactive
        self.selectedTab = nil
    }
}

@Observable
final class WorkspaceSessionsHolder {
    private let engine: TerminalEngine
    private let browserLauncher: BrowserLauncherProtocol
    private(set) var sessions: [UUID: WorkspaceSession] = [:]

    init(engine: TerminalEngine, browserLauncher: BrowserLauncherProtocol) {
        self.engine = engine
        self.browserLauncher = browserLauncher
    }

    /// Create (or return the existing) live session for a project: one
    /// interactive terminal at the root + auto-started managed processes.
    func openSession(for project: Project) -> WorkspaceSession {
        if let existing = sessions[project.id] { return existing }

        let root = URL(fileURLWithPath: project.directoryPath, isDirectory: true)
        let supervisor = ProcessSupervisor(engine: engine, browserLauncher: browserLauncher)
        supervisor.configure(panes: project.workspacePanes.sorted { $0.order < $1.order }, root: root)

        let interactive = engine.makeSession(
            TerminalSessionConfig(command: nil, cwd: root, readOnly: false)
        )
        interactive.start()
        supervisor.startAll()

        let session = WorkspaceSession(
            projectId: project.id, projectName: project.name, root: root,
            supervisor: supervisor, interactive: interactive
        )
        sessions[project.id] = session
        return session
    }

    func isOpen(_ projectId: UUID) -> Bool {
        sessions[projectId] != nil
    }

    /// Kill every process group of this workspace and drop the session.
    func close(projectId: UUID) {
        guard let session = sessions.removeValue(forKey: projectId) else { return }
        session.supervisor.shutdownAll()
        session.interactive.terminate()
    }

    /// App-quit teardown: no orphans holding ports.
    func shutdownAll() {
        for id in Array(sessions.keys) { close(projectId: id) }
    }
}
```

- [ ] **Step 4: Run holder tests to verify pass**

Run: `xcodebuild test ... -only-testing:DevtailTests/WorkspaceSessionsHolderTests`
Expected: PASS — 3 tests.

- [ ] **Step 5: Implement the views**

Create `Devtail/Features/Workspace/Views/TerminalHostView.swift`:

```swift
//
//  TerminalHostView.swift
//  Devtail
//
//  Bridges a session's retained NSView into SwiftUI. The representable may be
//  recreated freely by SwiftUI — the underlying NSView instance persists in
//  the holder, so scrollback and the PTY survive.
//

import AppKit
import SwiftUI

struct TerminalHostView: NSViewRepresentable {
    let terminalView: NSView

    func makeNSView(context: Context) -> NSView {
        terminalView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
```

Create `Devtail/Features/Workspace/Views/Components/ProcessCardView.swift`:

```swift
//
//  ProcessCardView.swift
//  Devtail
//
//  Sidebar card for one managed process: state dot, name, lifecycle actions.
//

import SwiftUI

struct ProcessCardView: View {
    let process: ManagedProcess
    let isSelected: Bool
    let onSelect: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DevtailTokens.Spacing.small) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 2) {
                    Text(process.name)
                        .font(DevtailTokens.Typography.body)
                        .lineLimit(1)
                    Text(stateLabel)
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                actions
            }
            .padding(DevtailTokens.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.primary.opacity(0.08) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var actions: some View {
        switch process.state {
        case .running, .starting:
            Button("Restart", systemImage: "arrow.clockwise", action: onRestart)
                .labelStyle(.iconOnly).buttonStyle(.plain).help("Restart")
            Button("Stop", systemImage: "stop.fill", action: onStop)
                .labelStyle(.iconOnly).buttonStyle(.plain).help("Stop")
        case .stopped, .exited:
            Button("Start", systemImage: "play.fill", action: onStart)
                .labelStyle(.iconOnly).buttonStyle(.plain).help("Start")
        }
    }

    private var stateColor: Color {
        switch process.state {
        case .running: .green
        case .starting: .yellow
        case .stopped: .gray
        case .exited: .red
        }
    }

    private var stateLabel: String {
        switch process.state {
        case .running: "running"
        case .starting: "starting…"
        case .stopped: "stopped"
        case .exited(let code): code.map { "exited (\($0))" } ?? "exited"
        }
    }
}
```

(If `DevtailTokens` member names differ — check `Devtail/DesignSystem/DevtailTokens.swift` — use the real token names; do not invent new tokens.)

Create `Devtail/Features/Workspace/Views/WorkspaceRootView.swift`:

```swift
//
//  WorkspaceRootView.swift
//  Devtail
//
//  The per-project work window: interactive terminal as the hero, a tab row
//  to flip between terminal and process logs, and a slim sidebar of process
//  cards. CRITICAL: terminal views are all mounted in a ZStack and merely
//  hidden — removing one from the hierarchy would destroy scrollback.
//

import SwiftUI

struct WorkspaceRootView: View {
    @Environment(WorkspaceSessionsHolder.self) private var holder
    let session: WorkspaceSession

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                tabRow
                terminalArea
            }
            .frame(minWidth: 640, maxWidth: .infinity, maxHeight: .infinity)

            sidebar
                .frame(minWidth: 220, maxWidth: 300)
        }
        .navigationTitle(session.projectName)
        .onDisappear { holder.close(projectId: session.projectId) }
    }

    private var tabRow: some View {
        HStack(spacing: DevtailTokens.Spacing.small) {
            tabButton(title: "terminal", id: nil)
            ForEach(session.supervisor.processes) { process in
                tabButton(title: process.name, id: process.id)
            }
            Spacer()
        }
        .padding(.horizontal, DevtailTokens.Spacing.medium)
        .padding(.vertical, DevtailTokens.Spacing.small)
    }

    private func tabButton(title: String, id: UUID?) -> some View {
        Button(title) { session.selectedTab = id }
            .buttonStyle(.plain)
            .font(DevtailTokens.Typography.caption)
            .foregroundStyle(session.selectedTab == id ? .primary : .secondary)
    }

    /// All terminal views stay mounted; opacity flips visibility. allowsHitTesting
    /// keeps hidden terminals from swallowing clicks.
    private var terminalArea: some View {
        ZStack {
            TerminalHostView(terminalView: session.interactive.view)
                .opacity(session.selectedTab == nil ? 1 : 0)
                .allowsHitTesting(session.selectedTab == nil)
            ForEach(session.supervisor.processes) { process in
                if let view = process.session?.view {
                    TerminalHostView(terminalView: view)
                        .opacity(session.selectedTab == process.id ? 1 : 0)
                        .allowsHitTesting(session.selectedTab == process.id)
                }
            }
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.small) {
                SectionHeader(title: "Processes")
                ForEach(session.supervisor.processes) { process in
                    ProcessCardView(
                        process: process,
                        isSelected: session.selectedTab == process.id,
                        onSelect: { session.selectedTab = process.id },
                        onStart: { session.supervisor.start(process) },
                        onStop: { session.supervisor.stop(process) },
                        onRestart: { session.supervisor.restart(process) }
                    )
                }
            }
            .padding(DevtailTokens.Spacing.medium)
        }
    }
}
```

Notes: the `ForEach` over processes inside `terminalArea` re-renders when `restart` swaps a session (new view identity) — the fresh view becomes visible, the old one is released with its terminated session. `SectionHeader` exists in `Devtail/DesignSystem/` (check its exact initializer). The branch/quick-links sidebar block from the spec ships in Task 6 with the launch wiring.

- [ ] **Step 6: Register the window scene and quit teardown**

Modify `Devtail/App/DevtailApp.swift`:

1. Add to `WindowID`:
```swift
enum WindowID {
    static let dashboard = "devtail.dashboard"
    static let settings  = "devtail.settings"
    static let workspace = "devtail.workspace"
}
```

2. In `DevtailApp`, add stored properties and init wiring (after the existing store setup inside `init()`):
```swift
    @State private var workspaceHolder: WorkspaceSessionsHolder
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
```
```swift
        let holder = WorkspaceSessionsHolder(
            engine: SwiftTermEngine(),
            browserLauncher: browserLauncher
        )
        _workspaceHolder = State(initialValue: holder)
        AppDelegate.workspaceHolder = holder
```

3. Add the scene after the dashboard `Window` (value-based group: one window per project id; reopening the same value focuses the existing window):
```swift
        WindowGroup("Workspace", id: WindowID.workspace, for: UUID.self) { $projectId in
            if let projectId,
               let project = projectStore.projects.first(where: { $0.id == projectId }) {
                WorkspaceRootView(session: workspaceHolder.openSession(for: project))
                    .environment(workspaceHolder)
            }
        }
        .modelContainer(modelContainer)
        .environment(projectStore)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 760)
```
(If `projectStore.projects` is not the store's published projects array name, check `ProjectStore.swift` for the actual property and use it.)

4. Add the app delegate at the bottom of the file — quit with servers running must kill every process group:
```swift
/// Quit-time teardown. SwiftUI has no reliable "app will quit" hook for
/// scene-owned state, so the holder is bridged through a static.
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var workspaceHolder: WorkspaceSessionsHolder?

    func applicationWillTerminate(_ notification: Notification) {
        AppDelegate.workspaceHolder?.shutdownAll()
    }
}
```

5. Also inject `.environment(workspaceHolder)` into the MenuBarExtra and dashboard `Window` scenes (Task 6's activity dot reads it).

- [ ] **Step 7: Full suite + build**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet`
Expected: PASS — everything green (11 new Workspace tests total so far).

- [ ] **Step 8: Commit**

```bash
git add Devtail/Features/Workspace Devtail/App/DevtailApp.swift DevtailTests/Features/Workspace
git commit -m "feat(workspace): per-project workspace window with retained terminal views"
```

---

### Task 6: Swap the launch path, retire AppleScript, migration test

**Files:**
- Modify: `Devtail/Features/ContextSwitcher/Stores/ProjectStore.swift:476-504` (`launchWorkspace`)
- Modify: `Devtail/App/DevtailApp.swift` (drop `WorkspaceLauncher`/`WorkspaceActivityMonitor` wiring)
- Modify: call sites of `launchWorkspace` / `WorkspaceActivityMonitor` (find with `rg -n "launchWorkspace|activityMonitor|WorkspaceActivityMonitor" Devtail/`)
- Delete: `Devtail/Core/Shell/WorkspaceLauncher.swift`, `Devtail/Features/ContextSwitcher/Services/WorkspaceActivityMonitor.swift`, `DevtailTests/Core/Shell/WorkspaceLauncherScriptTests.swift`, `DevtailTests/Core/Shell/MockWorkspaceLauncher.swift` (and any other launcher-mock file `rg -l "WorkspaceLauncherProtocol" DevtailTests/` reveals)
- Test: `DevtailTests/Features/Workspace/LegacyPaneMigrationTests.swift`

**Interfaces:**
- Consumes: Task 5's `WindowID.workspace` + `WorkspaceSessionsHolder.isOpen`.
- Produces: `ProjectStore.prepareLaunch(for project: Project)` (stamps `lastLaunchedAt`, persists branches — pure store-side prep; window opening stays in the view layer).

- [ ] **Step 1: Write the failing migration test**

Create `DevtailTests/Features/Workspace/LegacyPaneMigrationTests.swift`:

```swift
import Foundation
import Testing
@testable import Devtail

/// Spec: "proyecto legacy con layout/slots abre limpio como lista de procesos".
/// The supervisor must consume panes created under the old layout model —
/// arbitrary layoutSlot values, layout-specific ordering — as a plain,
/// order-sorted process list.
@MainActor
struct LegacyPaneMigrationTests {
    @Test func legacyPanesWithLayoutSlotsBecomeAPlainProcessList() {
        let engine = MockTerminalEngine()
        let supervisor = ProcessSupervisor(engine: engine, browserLauncher: MockBrowserLauncher())
        // Quarters-layout project from the old world: slots 0-3, shuffled order.
        let legacy = [
            WorkspacePane(label: "docker", relativeCwd: ".", command: "docker compose up",
                          order: 3, layoutSlot: 2, project: nil),
            WorkspacePane(label: "back", relativeCwd: "api", command: "npm run start:dev",
                          order: 0, layoutSlot: 0, project: nil),
            WorkspacePane(label: "front", relativeCwd: "web", command: "ng serve",
                          order: 1, layoutSlot: 1, project: nil),
        ]
        supervisor.configure(panes: legacy, root: URL(fileURLWithPath: "/tmp/legacy"))
        #expect(supervisor.processes.map(\.name) == ["back", "front", "docker"])
        #expect(supervisor.processes.map(\.state) == [.stopped, .stopped, .stopped])
    }
}
```

Run it: expected PASS immediately (Task 4 built this behavior) — it exists as the explicit migration regression gate. If it fails, Task 4's `configure` has a bug; fix there.

- [ ] **Step 2: Rework `ProjectStore.launchWorkspace`**

In `Devtail/Features/ContextSwitcher/Stores/ProjectStore.swift`, replace the `launchWorkspace(for:)` method (lines ~476-504) with:

```swift
    /// Store-side launch preparation. Window opening lives in the view layer
    /// (openWindow is a SwiftUI environment action); the embedded workspace's
    /// supervisor handles process spawn and frontend browser opening.
    func prepareLaunch(for project: Project) {
        // Stamp intent BEFORE opening anything. Even a failed launch counts —
        // the user tried to resume this project, which is the intent we record.
        project.lastLaunchedAt = .now
        try? repository.update(project)

        let panes = project.workspacePanes.sorted { $0.order < $1.order }
        persistBranches(for: project, panes: panes)
    }
```

Delete the `launcher` stored property and its `init` parameter from `ProjectStore`, the `isLaunchingWorkspace` state if nothing else reads it (`rg -n "isLaunchingWorkspace" Devtail/`), and the frontend pre-open loop (the supervisor owns browser opening now). Update `DevtailApp.swift`'s `ProjectStore(...)` construction accordingly. Keep `detectBranchChanges` and `persistBranches` untouched — the Resume drift flow is preserved.

- [ ] **Step 3: Swap the call sites**

Find every launch call site: `rg -n "launchWorkspace" Devtail/`. In each view (expected: `DashboardDetailView.swift`, possibly `MenuBarRootView.swift`/`ProjectRowView.swift`), replace the call with:

```swift
    @Environment(\.openWindow) private var openWindow   // add if missing
    // ...
    store.prepareLaunch(for: project)
    openWindow(id: WindowID.workspace, value: project.id)
```

The branch-drift confirmation flow (`detectBranchChanges` + alert) stays exactly where it is — it runs BEFORE this launch call, unchanged.

- [ ] **Step 4: Retire the AppleScript layer**

1. Delete the files listed in **Files → Delete** above.
2. `rg -n "WorkspaceActivityMonitor|activityMonitor" Devtail/` — remove the `@State private var activityMonitor` and `.environment(activityMonitor)` lines in `DevtailApp.swift`; where views read activity (e.g. `ActivityDot`), replace the source with the holder: `@Environment(WorkspaceSessionsHolder.self)` + `holder.isOpen(project.id)`.
3. `rg -n "WorkspaceLauncherProtocol|ghosttyNotInstalled|LaunchTarget" Devtail/` — remove dead references. If `LaunchTarget` is still referenced by `ProjectFormView`/model persistence, leave the MODEL field (dormant column per spec) but delete launcher-side use.
4. Build; chase remaining compile errors from the deletions — they are all dead references to the removed layer.

- [ ] **Step 5: Sidebar context block — current branch + quick links**

In `WorkspaceRootView.swift`, append below the process list inside `sidebar`'s `VStack` (spec: the sidebar carries the project's git branch and quick links). `WorkspaceRootView` needs the project's context for this — extend `WorkspaceSession` with the data instead of reaching back into SwiftData from the view:

1. Add to `WorkspaceSession` (Task 5 file): `let currentBranch: String?` and `let quickLinks: [(title: String, url: String)]`, populated in `WorkspaceSessionsHolder.openSession`:

```swift
        let branch = GitBranchDetector().detectBranch(in: root)
        let links = project.quickLinks
            .sorted { $0.order < $1.order }
            .map { (title: $0.title, url: $0.url) }
```

(Verify `QuickLink`'s real property names — `title`/`url`/`order` — in `Devtail/Features/ContextSwitcher/Models/QuickLink.swift` and match them; if `GitBranchDetector.detectBranch(in:)` has a different name, check `Devtail/Core/GitDetection/GitBranchDetector.swift` — it is the same call `ProjectStore.detectBranchChanges` uses.)

2. Render in the sidebar below the processes section:

```swift
                if let branch = session.currentBranch {
                    SectionHeader(title: "Branch")
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                if !session.quickLinks.isEmpty {
                    SectionHeader(title: "Quick Links")
                    ForEach(session.quickLinks, id: \.url) { link in
                        Link(link.title, destination: URL(string: link.url) ?? URL(fileURLWithPath: "/"))
                            .font(DevtailTokens.Typography.caption)
                    }
                }
```

3. Update `WorkspaceSessionsHolderTests` construction if the new `WorkspaceSession` initializer parameters require it (branch/links default to `nil`/`[]` in tests via the project fixture).

- [ ] **Step 6: Full suite**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet`
Expected: PASS. Deleted launcher tests are gone; no other test may break (tests that constructed `ProjectStore` with a launcher mock need their construction updated — the behavior they assert is unchanged).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(workspace): launch opens embedded workspace window, retire AppleScript path"
```

---

### Task 7: Manual verification checkpoint (user)

No files. Run the app (`xcodebuild -project Devtail.xcodeproj -scheme Devtail build` + open, or run from Xcode) and verify with a real project:

- [ ] Launch a project from the dashboard → workspace window opens: interactive terminal at the root (prompt has your full PATH — try `which node`), process cards in the sidebar, all defined processes auto-started.
- [ ] Process logs show ANSI colors; tab switching between terminal and logs preserves scrollback both ways.
- [ ] `Stop` on a watcher process (e.g. `ng serve`) → port freed (`lsof -i :4200` empty). `Restart` → log pane starts CLEAN.
- [ ] **Anti-orphan gate (success criterion #1)**: with a `--watch`-style server running, CLOSE the workspace window → `lsof -i :<port>` shows nothing. Repeat quitting the APP entirely with servers running → nothing.
- [ ] Frontend process with `localhostUrl` → browser opened on start.
- [ ] Branch drift: switch branches in the repo, hit Resume → confirmation alert still appears.
- [ ] Legacy project created before this change launches with its panes as processes.
