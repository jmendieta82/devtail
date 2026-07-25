# Multiple Agent Tabs per Project Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a project workspace run N simultaneous Claude agent tabs — a "+" chip creates new agent tabs, each closable (except the last), each resuming exactly its own conversation.

**Architecture:** Replace the singleton `WorkspaceSession.agent`/`agentExited` with an `agents: [AgentInstance]` collection mirroring the existing `ProcessSupervisor`/`ManagedProcess` pattern, and parameterize `WorkspaceTab.agent` → `.agent(UUID)` mirroring `.process(UUID)`. Each instance carries its own generated Claude session id: launch appends `--session-id <uuid>`, restart-with-context uses `--resume <uuid>`.

**Tech Stack:** Swift 5 language mode, SwiftUI, `@Observable`, Swift Testing (`@Test`/`#expect`), xcodebuild.

**Spec:** `docs/superpowers/specs/2026-07-24-multi-agent-tabs-design.md`

## Global Constraints

- Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, macOS 26.0 Tahoe minimum.
- State via the `@Observable` macro, never `ObservableObject`/`@Published`.
- Conventional Commits; NEVER add "Co-Authored-By" or AI attribution.
- One type per file unless tightly coupled.
- Full suite command, run from `/Volumes/Datos/Frelancer/DEVTAIL/Devtail`:
  `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -5`
  Never run two xcodebuild invocations in parallel (`pgrep -x xcodebuild` first). Suite is currently 555 tests / 0 failures.
- Work happens on branch `feat/multi-agent-tabs`.
- Invariant throughout: an open `WorkspaceSession` always has `agents.count >= 1`.
- Claude session ids passed to the CLI are lowercased UUID strings (`uuidString.lowercased()`).

---

### Task 1: AgentInstance model + agents collection + per-instance session ids (holder layer)

Replaces the stored `agent`/`agentExited` pair with an `agents` array while keeping read-only computed bridges so the views still compile untouched. All launch/restart commands gain per-instance session ids.

**Files:**
- Create: `Devtail/Features/Workspace/Models/AgentInstance.swift`
- Modify: `Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift`
- Modify: `DevtailTests/Features/Workspace/WorkspaceSessionGitStatusTests.swift` (makeSession helper only — the init signature change below breaks its direct `WorkspaceSession(... agent: TerminalSession ...)` construction)
- Modify: `DevtailTests/Features/Workspace/WorkspaceSessionClaudeInfoTests.swift` (same makeSession helper pattern)
- Test: `DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift`

**Interfaces:**
- Consumes: `TerminalSession`, `TerminalEngine`, `TerminalSessionConfig` (existing).
- Produces (later tasks rely on these exact names):
  - `final class AgentInstance: Identifiable` with `id: UUID`, `title: String`, `session: TerminalSession`, `exited: Bool`, `claudeSessionId: UUID`, `func rotateClaudeSessionId() -> UUID`.
  - `WorkspaceSession.agents: [AgentInstance]` (`fileprivate(set)`).
  - `WorkspaceSessionsHolder.restartAgent(projectId: UUID, agentId: UUID? = nil, resume: Bool = false)` (nil agentId → first agent).
  - `static func agentLaunchCommand(configured: String, sessionId: UUID, resume: Bool) -> String`.
  - Temporary bridges `WorkspaceSession.agent: TerminalSession` and `agentExited: Bool` (computed, read-only) — **removed in Task 2**.

- [ ] **Step 1: Write the failing tests for the new launch-command shape**

Replace the whole `// MARK: - Restart with context (resume command construction)` block in `WorkspaceSessionsHolderTests.swift` with:

```swift
// MARK: - Launch command construction (per-instance session ids)

@Test func createCommandAppendsSessionIdToPlainClaude() {
    let id = UUID()
    #expect(WorkspaceSessionsHolder.agentLaunchCommand(configured: "claude", sessionId: id, resume: false)
        == "claude --session-id \(id.uuidString.lowercased())")
}

@Test func resumeCommandAppendsResumeWithSameId() {
    let id = UUID()
    #expect(WorkspaceSessionsHolder.agentLaunchCommand(configured: "claude", sessionId: id, resume: true)
        == "claude --resume \(id.uuidString.lowercased())")
}

/// A configured command that already carries its own session/resume flags
/// wins — no append, in either mode.
@Test func commandWithExistingSessionTokensIsLeftAlone() {
    let id = UUID()
    for configured in ["claude --continue", "claude -c", "claude --resume abc", "claude -r", "claude --session-id abc"] {
        #expect(WorkspaceSessionsHolder.agentLaunchCommand(configured: configured, sessionId: id, resume: false) == configured)
        #expect(WorkspaceSessionsHolder.agentLaunchCommand(configured: configured, sessionId: id, resume: true) == configured)
    }
}

/// Token-based detection, not substring: `--coverage` or a path containing
/// `-c`/`-r` must not suppress the append.
@Test func sessionTokenCheckIgnoresSubstringMatches() {
    let id = UUID()
    let suffix = "--session-id \(id.uuidString.lowercased())"
    #expect(WorkspaceSessionsHolder.agentLaunchCommand(configured: "claude --coverage", sessionId: id, resume: false)
        == "claude --coverage \(suffix)")
    #expect(WorkspaceSessionsHolder.agentLaunchCommand(configured: "/opt/tools-c/claude", sessionId: id, resume: false)
        == "/opt/tools-c/claude \(suffix)")
}

/// Same blank-setting sanitize-and-fallback as before.
@Test func launchCommandFallsBackToClaudeWhenConfiguredIsBlank() {
    let id = UUID()
    #expect(WorkspaceSessionsHolder.agentLaunchCommand(configured: "   ", sessionId: id, resume: false)
        == "claude --session-id \(id.uuidString.lowercased())")
    #expect(WorkspaceSessionsHolder.agentLaunchCommand(configured: "", sessionId: id, resume: true)
        == "claude --resume \(id.uuidString.lowercased())")
}
```

- [ ] **Step 2: Update the existing agent tests to the instance-based shape**

Still in `WorkspaceSessionsHolderTests.swift`:

Replace `openSessionSpawnsAgentWithDefaultClaude`'s body:

```swift
@Test func openSessionSpawnsAgentWithDefaultClaude() {
    let (holder, engine) = makeSUT()
    let session = holder.openSession(for: project("alpha"))
    let expected = "claude --session-id \(session.agents[0].claudeSessionId.uuidString.lowercased())"
    #expect(engine.configs.contains { $0.command == expected && !$0.readOnly })
}
```

Replace `restartAgentWithResumeSpawnsAgentWithContinueCommand` with:

```swift
@Test func restartAgentWithResumeSpawnsAgentWithResumeOfSameId() {
    let (holder, engine) = makeSUT(agentCommand: "claude")
    let session = holder.openSession(for: project("alpha"))
    let old = session.agents[0].session as? MockTerminalSession
    let originalId = session.agents[0].claudeSessionId

    holder.restartAgent(projectId: session.projectId, resume: true)

    #expect(session.agents[0].session !== old)
    #expect(session.agents[0].exited == false)
    #expect(old?.terminateCount == 1)
    #expect(session.agents[0].claudeSessionId == originalId)
    #expect(engine.configs.last?.command == "claude --resume \(originalId.uuidString.lowercased())")
    #expect((session.agents[0].session as? MockTerminalSession)?.startCount == 1)
}

/// Plain restart is a fresh conversation: the tracked id rotates and the
/// fresh spawn carries the NEW id.
@Test func restartAgentWithoutResumeRotatesClaudeSessionId() {
    let (holder, engine) = makeSUT(agentCommand: "claude")
    let session = holder.openSession(for: project("alpha"))
    let originalId = session.agents[0].claudeSessionId

    holder.restartAgent(projectId: session.projectId)

    let newId = session.agents[0].claudeSessionId
    #expect(newId != originalId)
    #expect(engine.configs.last?.command == "claude --session-id \(newId.uuidString.lowercased())")
}
```

Add after `restartAgentCreatesFreshSessionAndResetsFlag`:

```swift
/// restartAgent with an explicit unknown agentId is a safe no-op.
@Test func restartAgentWithUnknownAgentIdIsNoOp() {
    let (holder, engine) = makeSUT()
    let session = holder.openSession(for: project("alpha"))
    let before = engine.sessions.count

    holder.restartAgent(projectId: session.projectId, agentId: UUID())

    #expect(engine.sessions.count == before)
    #expect((session.agents[0].session as? MockTerminalSession)?.terminateCount == 0)
}
```

The remaining tests that read `session.agent` / `session.agentExited` (`agentExitSetsAgentExitedFlag`, `restartAgentCreatesFreshSessionAndResetsFlag`, `staleAgentExitAfterRestartDoesNotReflipFlag`, `closeTerminatesAgentSession`, the quit-path block, `openSessionSpawnsAgentWithConfiguredCommand`) keep compiling via the read-only bridges — leave them untouched in this task.

- [ ] **Step 3: Run the suite to verify the new tests fail**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -20`
Expected: compile FAILURE (`agentLaunchCommand(configured:sessionId:resume:)` and `session.agents` don't exist yet).

- [ ] **Step 4: Create AgentInstance**

Create `Devtail/Features/Workspace/Models/AgentInstance.swift`:

```swift
//
//  AgentInstance.swift
//  Devtail
//
//  Runtime state of one Claude agent tab. Ephemeral by design (never
//  persisted): mirrors ManagedProcess's shape — an @Observable identity
//  wrapper the UI and holder share, with the session replaced wholesale on
//  restart. `claudeSessionId` is OUR generated conversation id, handed to
//  the CLI via --session-id so restart-with-context can --resume exactly
//  this tab's conversation (--continue is ambiguous with N tabs in one cwd).
//

import Foundation

@Observable
final class AgentInstance: Identifiable {
    let id = UUID()
    let title: String
    /// The live PTY session. Replaced wholesale on restart, never mutated.
    var session: TerminalSession
    /// Set when the agent process exits. No auto-respawn — drives the
    /// dead-state overlay only.
    var exited = false
    /// The Claude conversation id this tab launched with. Stable across
    /// restart-with-context; rotated by plain restart (fresh conversation).
    private(set) var claudeSessionId: UUID

    init(title: String, session: TerminalSession, claudeSessionId: UUID) {
        self.title = title
        self.session = session
        self.claudeSessionId = claudeSessionId
    }

    /// Fresh conversation id for a plain (non-resume) restart.
    func rotateClaudeSessionId() -> UUID {
        claudeSessionId = UUID()
        return claudeSessionId
    }
}
```

- [ ] **Step 5: Migrate WorkspaceSession + holder to the agents collection**

In `Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift`:

Replace the stored properties `agent` (line 51) and `agentExited` (line 54) on `WorkspaceSession` with:

```swift
    /// The Claude agent tabs, in tab-row order. Always at least one — the
    /// first is seeded at session open; the last one cannot be closed.
    /// Same replace-wholesale-on-restart contract per instance as
    /// `interactive` — `fileprivate(set)` for the same reason.
    fileprivate(set) var agents: [AgentInstance]
    /// TEMPORARY bridges while views still address "the" agent — removed
    /// when WorkspaceTab.agent is parameterized (next task).
    var agent: TerminalSession { agents[0].session }
    var agentExited: Bool { agents[0].exited }
    /// Monotonic tab-title counter: "agent", then "agent 2", "agent 3", …
    /// Numbers are never reused after a close.
    private var nextAgentNumber = 2

    fileprivate func nextAgentTitle() -> String {
        defer { nextAgentNumber += 1 }
        return "agent \(nextAgentNumber)"
    }

    func agentInstance(with id: UUID) -> AgentInstance? {
        agents.first { $0.id == id }
    }
```

Change the init parameter `agent: TerminalSession` to `agent: AgentInstance` and the assignment `self.agent = agent` to `self.agents = [agent]`.

That signature change breaks two other test files that construct `WorkspaceSession` directly. Update their `makeSession` helpers (the failing line is `supervisor: supervisor, agent: agent,` in both) so the suite stays green after this task.

In `DevtailTests/Features/Workspace/WorkspaceSessionGitStatusTests.swift`, replace the `let agent = engine.makeSession(...)` line and the `WorkspaceSession(...)` call inside `makeSession(reader:)` with:

```swift
        let terminal = engine.makeSession(TerminalSessionConfig(command: "claude", cwd: URL(fileURLWithPath: "/tmp/alpha"), readOnly: false))
        let agent = AgentInstance(title: "agent", session: terminal, claudeSessionId: UUID())
        return WorkspaceSession(
            projectId: UUID(), projectName: "alpha", root: URL(fileURLWithPath: "/tmp/alpha"),
            supervisor: supervisor, agent: agent,
            gitStatusReader: reader
        )
```

In `DevtailTests/Features/Workspace/WorkspaceSessionClaudeInfoTests.swift`, apply the identical change inside `makeSession(introspector:)`:

```swift
        let terminal = engine.makeSession(TerminalSessionConfig(command: "claude", cwd: URL(fileURLWithPath: "/tmp/alpha"), readOnly: false))
        let agent = AgentInstance(title: "agent", session: terminal, claudeSessionId: UUID())
        return WorkspaceSession(
            projectId: UUID(), projectName: "alpha", root: URL(fileURLWithPath: "/tmp/alpha"),
            supervisor: supervisor, agent: agent,
            claudeIntrospector: introspector
        )
```

In `WorkspaceSessionsHolder.openSession(for:)`, replace the agent-spawn block (the `let command …` / `let agent = engine.makeSession(…)` / `if !isShuttingDown { agent.start() }` lines) with:

```swift
        let claudeSessionId = UUID()
        let command = Self.agentLaunchCommand(
            configured: settings.agentCommand, sessionId: claudeSessionId, resume: false
        )
        let agentTerminal = engine.makeSession(
            TerminalSessionConfig(command: command, cwd: root, readOnly: false, imagePaste: true)
        )
        if !isShuttingDown { agentTerminal.start() }
        let agentInstance = AgentInstance(
            title: "agent", session: agentTerminal, claudeSessionId: claudeSessionId
        )
```

(the old "runtime-blank setting" comment moves onto `agentLaunchCommand`, which now owns the sanitize-and-fallback for ALL spawns), pass `agent: agentInstance` to the `WorkspaceSession` init, and change `wireAgentExit(agent, on: session)` to `wireAgentExit(agentTerminal, on: agentInstance)`.

Replace `wireAgentExit` (lines 446–451):

```swift
    /// Mirrors `wireInteractiveExit` per agent instance: same identity guard
    /// against stale exits from a since-replaced (restarted) session.
    private func wireAgentExit(_ terminal: TerminalSession, on instance: AgentInstance) {
        terminal.onExit = { [weak instance, weak terminal] _ in
            guard let instance, let terminal, instance.session === terminal else { return }
            instance.exited = true
        }
    }
```

Replace `agentLaunchCommand` (lines 459–466):

```swift
    /// Builds an agent launch command from the configured setting: sanitizes
    /// a runtime-blank setting to "claude" (a blank must not silently spawn
    /// a plain shell in an agent tab), then appends the per-instance
    /// conversation flag — `--session-id <uuid>` on create, `--resume
    /// <uuid>` on restart-with-context. If the configured command already
    /// carries its own session/continue/resume token the user wins and
    /// nothing is appended — token-wise, not substring-wise, so `--coverage`
    /// or a path containing `-c` doesn't suppress the append.
    static func agentLaunchCommand(configured: String, sessionId: UUID, resume: Bool) -> String {
        let trimmed = configured.trimmingCharacters(in: .whitespaces)
        let command = trimmed.isEmpty ? "claude" : trimmed
        let tokens = command.split(whereSeparator: \.isWhitespace)
        let sessionTokens: Set<Substring> = ["--continue", "-c", "--resume", "-r", "--session-id"]
        guard !tokens.contains(where: { sessionTokens.contains($0) }) else { return command }
        let id = sessionId.uuidString.lowercased()
        return resume ? "\(command) --resume \(id)" : "\(command) --session-id \(id)"
    }
```

Replace `restartAgent` (lines 475–488):

```swift
    /// User-initiated restart of one agent tab. Mirrors `restartInteractive`:
    /// terminate the old session, spawn a fresh one, re-wire, reset the flag.
    /// Works on a live agent too (the terminate-first shape makes it the
    /// stuck-agent escape hatch). `agentId: nil` targets the first agent.
    /// With `resume`, the fresh agent relaunches with `--resume` on the
    /// instance's tracked conversation id — exactly its own conversation;
    /// without it, the id rotates: a plain restart is a fresh conversation.
    func restartAgent(projectId: UUID, agentId: UUID? = nil, resume: Bool = false) {
        guard let session = sessions[projectId] else { return }
        let target: AgentInstance?
        if let agentId {
            target = session.agentInstance(with: agentId)
        } else {
            target = session.agents.first
        }
        guard let instance = target else { return }

        instance.session.terminate()

        let sessionId = resume ? instance.claudeSessionId : instance.rotateClaudeSessionId()
        let command = Self.agentLaunchCommand(
            configured: settings.agentCommand, sessionId: sessionId, resume: resume
        )
        let fresh = engine.makeSession(
            TerminalSessionConfig(command: command, cwd: session.root, readOnly: false, imagePaste: true)
        )
        fresh.start()
        instance.session = fresh
        wireAgentExit(fresh, on: instance)
        instance.exited = false
    }
```

In `close(projectId:)` replace `session.agent.terminate()` with:

```swift
        for instance in session.agents { instance.session.terminate() }
```

In `liveTerminalSessions()` replace the agent block (`if !session.agentExited { live.append(session.agent) }`) with:

```swift
            for instance in session.agents where !instance.exited {
                live.append(instance.session)
            }
```

- [ ] **Step 6: Run the suite**

Run: `pgrep -x xcodebuild || xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -5`
Expected: PASS, 0 failures (previous count + 3 net new tests).

- [ ] **Step 7: Commit**

```bash
git add Devtail/Features/Workspace/Models/AgentInstance.swift Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift
git commit -m "refactor(workspace): agent instances with per-tab claude session ids"
```

---

### Task 2: Parameterize WorkspaceTab.agent(UUID) and migrate every call site

The breaking identity change, done as one compilable slice: tab case, fallback resolver, views (chips ForEach, ZStack hosts ForEach, per-instance dead overlay), menu commands, shortcuts copy — and the Task 1 bridges are deleted.

**Files:**
- Modify: `Devtail/Features/Workspace/Models/WorkspaceTab.swift`
- Modify: `Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift`
- Modify: `Devtail/Features/Workspace/Views/WorkspaceRootView.swift`
- Modify: `Devtail/App/WorkspaceCommands.swift`
- Modify: `Devtail/Features/Workspace/Views/Components/WorkspaceSettingsTabView.swift`
- Modify: `Devtail/Features/Workspace/Views/Components/WorkspaceDashboardColumn.swift`
- Test: `DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift`

**Interfaces:**
- Consumes: `AgentInstance`, `WorkspaceSession.agents`, `agentInstance(with:)` (Task 1).
- Produces: `WorkspaceTab.agent(UUID)`; `WorkspaceSession.firstAgentTab: WorkspaceTab`. The `agent`/`agentExited` bridges are GONE after this task.

- [ ] **Step 1: Update the tests to the parameterized tab**

In `WorkspaceSessionsHolderTests.swift`:

`openSessionStartsOnAgentTab` becomes:

```swift
@Test func openSessionStartsOnFirstAgentTab() {
    let (holder, _) = makeSUT()
    let session = holder.openSession(for: project("alpha"))
    #expect(session.selectedTab == .agent(session.agents[0].id))
    #expect(session.firstAgentTab == .agent(session.agents[0].id))
}
```

In `closeInteractiveTerminatesNilsAndResetsFlag` and `closeInteractiveDoesNotChangeSelectionWhenAnotherTabIsSelected`, replace `session.selectedTab = .agent` with `session.selectedTab = session.firstAgentTab` and `#expect(session.selectedTab == .agent)` with `#expect(session.selectedTab == session.firstAgentTab)`.

In `selectedTabCanSwitchToSettingsAndBackToAgent`, replace both `.agent` reads/writes the same way (`session.firstAgentTab`).

In the tests still using the bridges (`agentExitSetsAgentExitedFlag`, `restartAgentCreatesFreshSessionAndResetsFlag`, `staleAgentExitAfterRestartDoesNotReflipFlag`, `closeTerminatesAgentSession`, `hasLiveSessionsReflectsAgentLifecycle`, `shutdownAll*`, `openSessionDuringShutdownIsInertAndSweptAtDeadline`), replace every `session.agent` with `session.agents[0].session`, every `session.agentExited` with `session.agents[0].exited`, and every `late.agent` with `late.agents[0].session`.

- [ ] **Step 2: Run the suite to verify it fails**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -10`
Expected: compile FAILURE (`firstAgentTab` and `.agent(UUID)` don't exist yet).

- [ ] **Step 3: Parameterize the tab case**

In `Devtail/Features/Workspace/Models/WorkspaceTab.swift` replace `case agent` with:

```swift
    /// First-class interactive agent tab (auto-launched agent command).
    /// Parameterized by AgentInstance id — a project can run several.
    case agent(UUID)
```

- [ ] **Step 4: Session-side resolver + default selection**

In `WorkspaceSessionsHolder.swift` on `WorkspaceSession`:

Delete the two TEMPORARY bridge properties (`agent`, `agentExited`) added in Task 1.

Change the `selectedTab` declaration (line 58) to drop its default:

```swift
    /// Which center-column tab is showing. The agent tabs are the only
    /// constant ones, so the first agent is the default — assigned in init
    /// (the id doesn't exist at declaration time).
    var selectedTab: WorkspaceTab
```

and in `init`, after `self.agents = [agent]`, add:

```swift
        self.selectedTab = .agent(agent.id)
```

Add next to `agentInstance(with:)`:

```swift
    /// The universal tab fallback: every "go back to the agent" path
    /// (closing files/ephemeral tabs, dismissing settings) lands on the
    /// FIRST agent tab. Safe unconditionally — agents is never empty.
    var firstAgentTab: WorkspaceTab { .agent(agents[0].id) }
```

In `closeFile(at:)` replace `selectedTab = .agent` with `selectedTab = firstAgentTab`. In `closeInteractive(projectId:)` replace `session.selectedTab = .agent` with `session.selectedTab = session.firstAgentTab`.

- [ ] **Step 5: Migrate WorkspaceRootView**

In `tabRow`, replace the hardcoded agent `WorkspaceTabChip` (lines 125–131) with:

```swift
                ForEach(session.agents) { agent in
                    WorkspaceTabChip(
                        icon: "sparkles",
                        title: agent.title,
                        isSelected: session.selectedTab == .agent(agent.id),
                        select: { session.selectedTab = .agent(agent.id) },
                        close: nil
                    )
                }
```

In the same `tabRow`, the tasks and settings chips' `close:` closures become `{ session.selectedTab = session.firstAgentTab }`.

In `processTab(for:)`, the close closure's fallback becomes `session.selectedTab = session.firstAgentTab`.

In `terminalStack(appearance:)`, replace the single agent host (lines 272–275) with:

```swift
            ForEach(session.agents) { agent in
                TerminalHostView(terminalView: agent.session.view, appearance: appearance, isActive: session.selectedTab == .agent(agent.id))
                    .id(ObjectIdentifier(agent.session))
                    .opacity(session.selectedTab == .agent(agent.id) ? 1 : 0)
                    .allowsHitTesting(session.selectedTab == .agent(agent.id))
            }
```

(the `.id(ObjectIdentifier(…))` remount contract from 66561b8 is per instance now; `isActive` stays mutually exclusive because at most one tab id is selected, so first-responder can't be fought over).

Replace the dead-agent trigger (lines 307–309) with:

```swift
            if case .agent(let agentId) = session.selectedTab,
               let instance = session.agentInstance(with: agentId), instance.exited {
                deadAgentOverlay(for: instance)
            }
```

Replace `private var deadAgentOverlay: some View` with a parameterized version — only the signature and the two button actions change:

```swift
    private func deadAgentOverlay(for instance: AgentInstance) -> some View {
        VStack(spacing: DevtailTokens.Spacing.gapMedium) {
            Text("agent exited")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                Button("Restart") {
                    holder.restartAgent(projectId: session.projectId, agentId: instance.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Restart with context") {
                    holder.restartAgent(projectId: session.projectId, agentId: instance.id, resume: true)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(DevtailTokens.Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                .fill(DevtailTokens.Colors.popoverBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                .stroke(DevtailTokens.Colors.borderSubtle, lineWidth: DevtailTokens.BorderWidth.default)
        )
    }
```

- [ ] **Step 6: Migrate WorkspaceCommands + shortcuts copy**

In `WorkspaceCommands.swift`, the Agent button (⇧⌘A):

```swift
            Button("Agent") {
                guard let session else { return }
                session.selectedTab = session.firstAgentTab
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            .disabled(session == nil)
```

The Restart button (⇧⌘R) — acts on the selected agent tab, first agent otherwise:

```swift
            // Always-available escape hatch: works on a live or stuck agent
            // too, not just after exit — restartAgent terminates first.
            // Targets the SELECTED agent tab when one is selected; the
            // first agent otherwise.
            Button("Restart Agent with Context") {
                guard let session else { return }
                var agentId: UUID?
                if case .agent(let id) = session.selectedTab { agentId = id }
                holder.restartAgent(projectId: session.projectId, agentId: agentId, resume: true)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(session == nil)
```

In `WorkspaceSettingsTabView.swift` (line 58), `onDismiss` becomes `{ session.selectedTab = session.firstAgentTab }`.

In `WorkspaceDashboardColumn.swift` `shortcutsSection`, update the two agent rows to reflect the new semantics:

```swift
                shortcutRow("\u{21E7}\u{2318}A", "First agent tab")
```

```swift
                shortcutRow("\u{21E7}\u{2318}R", "Restart selected agent with context")
```

- [ ] **Step 7: Run the suite**

Run: `pgrep -x xcodebuild || xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -5`
Expected: PASS, 0 failures.

- [ ] **Step 8: Commit**

```bash
git add Devtail/Features/Workspace/Models/WorkspaceTab.swift Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift Devtail/Features/Workspace/Views/WorkspaceRootView.swift Devtail/App/WorkspaceCommands.swift Devtail/Features/Workspace/Views/Components/WorkspaceSettingsTabView.swift Devtail/Features/Workspace/Views/Components/WorkspaceDashboardColumn.swift DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift
git commit -m "refactor(workspace): parameterize agent tab identity by instance"
```

---

### Task 3: openAgent (the "+" chip)

**Files:**
- Modify: `Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift`
- Modify: `Devtail/Features/Workspace/Views/WorkspaceRootView.swift`
- Test: `DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift`

**Interfaces:**
- Consumes: `AgentInstance`, `nextAgentTitle()`, `agentLaunchCommand(configured:sessionId:resume:)`, `wireAgentExit(_:on:)` (Task 1), `.agent(UUID)` / `firstAgentTab` (Task 2).
- Produces: `@discardableResult func openAgent(projectId: UUID) -> AgentInstance?` on `WorkspaceSessionsHolder`.

- [ ] **Step 1: Write the failing tests**

Add to `WorkspaceSessionsHolderTests.swift`:

```swift
// MARK: - Multiple agent tabs (openAgent)

@Test func openAgentAppendsInstanceWithOwnSessionIdAndSelectsIt() throws {
    let (holder, engine) = makeSUT(agentCommand: "claude")
    let session = holder.openSession(for: project("alpha"))
    let firstId = session.agents[0].claudeSessionId

    let second = try #require(holder.openAgent(projectId: session.projectId))

    #expect(session.agents.count == 2)
    #expect(session.agents[1] === second)
    #expect(second.title == "agent 2")
    #expect(second.claudeSessionId != firstId)
    #expect(session.selectedTab == .agent(second.id))
    let mock = try #require(second.session as? MockTerminalSession)
    #expect(mock.startCount == 1)
    #expect(engine.configs.last?.command == "claude --session-id \(second.claudeSessionId.uuidString.lowercased())")
    #expect(engine.configs.last?.readOnly == false)
    #expect(engine.configs.last?.cwd.path == "/tmp/alpha")
}

/// Titles are monotonic: agent 2, agent 3, … (the never-reused-after-close
/// half of this rule is asserted in Task 4, once closeAgent exists).
@Test func agentTitlesAreMonotonic() throws {
    let (holder, _) = makeSUT()
    let session = holder.openSession(for: project("alpha"))
    let second = try #require(holder.openAgent(projectId: session.projectId))
    let third = try #require(holder.openAgent(projectId: session.projectId))
    #expect(second.title == "agent 2")
    #expect(third.title == "agent 3")
}

@Test func openAgentOnUnknownProjectReturnsNil() {
    let (holder, engine) = makeSUT()
    #expect(holder.openAgent(projectId: UUID()) == nil)
    #expect(engine.sessions.isEmpty)
}

/// A "+" click racing the quit window must not spawn a child the SIGTERM
/// wave can no longer see — same rule as openSession during shutdown.
@Test func openAgentDuringShutdownIsRefused() {
    let (holder, engine) = makeSUT(schedule: { _, _ in })
    let session = holder.openSession(for: project("alpha"))
    holder.shutdownAll(deadline: 2.0) {}

    #expect(holder.openAgent(projectId: session.projectId) == nil)
    #expect(engine.sessions.count == 1)
}
```

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -10`
Expected: compile FAILURE (`openAgent(projectId:)` doesn't exist).

- [ ] **Step 3: Implement openAgent**

In `WorkspaceSessionsHolder`, after `closeInteractive`:

```swift
    /// "+" chip: spawn one more agent tab. Mirrors the openSession agent
    /// seed (same config shape, same exit wiring) plus selection of the new
    /// tab. Refused during the quit window — a child spawned after the
    /// SIGTERM wave would be an orphan (same rule as openSession's
    /// isShuttingDown guard). Returns nil when refused or the project has
    /// no live session.
    @discardableResult
    func openAgent(projectId: UUID) -> AgentInstance? {
        guard let session = sessions[projectId], !isShuttingDown else { return nil }

        let claudeSessionId = UUID()
        let command = Self.agentLaunchCommand(
            configured: settings.agentCommand, sessionId: claudeSessionId, resume: false
        )
        let terminal = engine.makeSession(
            TerminalSessionConfig(command: command, cwd: session.root, readOnly: false, imagePaste: true)
        )
        terminal.start()
        let instance = AgentInstance(
            title: session.nextAgentTitle(), session: terminal, claudeSessionId: claudeSessionId
        )
        wireAgentExit(terminal, on: instance)
        session.agents.append(instance)
        session.selectedTab = .agent(instance.id)
        return instance
    }
```

- [ ] **Step 4: Add the "+" chip to the tab row**

In `WorkspaceRootView.tabRow`, right after the agents `ForEach` (before the processes `ForEach`):

```swift
                Button {
                    holder.openAgent(projectId: session.projectId)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.icon)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
                .help("New agent tab")
```

- [ ] **Step 5: Run the suite**

Run: `pgrep -x xcodebuild || xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -5`
Expected: PASS, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift Devtail/Features/Workspace/Views/WorkspaceRootView.swift DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift
git commit -m "feat(workspace): open additional agent tabs with a plus chip"
```

---

### Task 4: closeAgent (closable chips, last one protected)

**Files:**
- Modify: `Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift`
- Modify: `Devtail/Features/Workspace/Views/WorkspaceRootView.swift`
- Test: `DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift`

**Interfaces:**
- Consumes: `openAgent(projectId:)` (Task 3), `agentInstance(with:)`, `firstAgentTab` (Tasks 1–2).
- Produces: `func closeAgent(projectId: UUID, agentId: UUID)` on `WorkspaceSessionsHolder`.

- [ ] **Step 1: Write the failing tests**

Add to `WorkspaceSessionsHolderTests.swift`:

```swift
// MARK: - closeAgent

@Test func closeAgentTerminatesAndRemovesInstance() throws {
    let (holder, _) = makeSUT()
    let session = holder.openSession(for: project("alpha"))
    let second = try #require(holder.openAgent(projectId: session.projectId))
    let mock = try #require(second.session as? MockTerminalSession)

    holder.closeAgent(projectId: session.projectId, agentId: second.id)

    #expect(session.agents.count == 1)
    #expect(session.agentInstance(with: second.id) == nil)
    #expect(mock.terminateCount == 1)
}

/// The last agent tab cannot be closed — the invariant every fallback
/// (firstAgentTab) relies on.
@Test func closeAgentRefusesToCloseTheLastInstance() {
    let (holder, _) = makeSUT()
    let session = holder.openSession(for: project("alpha"))
    let only = session.agents[0]

    holder.closeAgent(projectId: session.projectId, agentId: only.id)

    #expect(session.agents.count == 1)
    #expect((only.session as? MockTerminalSession)?.terminateCount == 0)
}

/// Closing the selected tab selects the previous neighbor (or the next one
/// when the closed tab was first) — same rule as closeFile.
@Test func closeAgentSelectsNeighborWhenSelectedTabCloses() throws {
    let (holder, _) = makeSUT()
    let session = holder.openSession(for: project("alpha"))
    let second = try #require(holder.openAgent(projectId: session.projectId))
    let third = try #require(holder.openAgent(projectId: session.projectId))

    session.selectedTab = .agent(second.id)
    holder.closeAgent(projectId: session.projectId, agentId: second.id)
    #expect(session.selectedTab == .agent(session.agents[0].id))

    session.selectedTab = .agent(session.agents[0].id)
    holder.closeAgent(projectId: session.projectId, agentId: session.agents[0].id)
    #expect(session.selectedTab == .agent(third.id))
}

@Test func closeAgentKeepsSelectionWhenAnotherTabIsSelected() throws {
    let (holder, _) = makeSUT()
    let session = holder.openSession(for: project("alpha"))
    let second = try #require(holder.openAgent(projectId: session.projectId))
    session.selectedTab = session.firstAgentTab

    holder.closeAgent(projectId: session.projectId, agentId: second.id)

    #expect(session.selectedTab == session.firstAgentTab)
}

@Test func closeAgentWithUnknownIdIsSafeNoOp() {
    let (holder, _) = makeSUT()
    let session = holder.openSession(for: project("alpha"))
    _ = holder.openAgent(projectId: session.projectId)

    holder.closeAgent(projectId: session.projectId, agentId: UUID())

    #expect(session.agents.count == 2)
}
```

Also extend `agentTitlesAreMonotonic` (Task 3) into the never-reused variant:

```swift
@Test func agentTitlesAreMonotonicAndNeverReused() throws {
    let (holder, _) = makeSUT()
    let session = holder.openSession(for: project("alpha"))
    let second = try #require(holder.openAgent(projectId: session.projectId))
    let third = try #require(holder.openAgent(projectId: session.projectId))
    #expect(second.title == "agent 2")
    #expect(third.title == "agent 3")

    holder.closeAgent(projectId: session.projectId, agentId: second.id)

    let fourth = try #require(holder.openAgent(projectId: session.projectId))
    #expect(fourth.title == "agent 4")
}
```

(delete the interim `agentTitlesAreMonotonic` test — this supersedes it).

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -10`
Expected: compile FAILURE (`closeAgent(projectId:agentId:)` doesn't exist).

- [ ] **Step 3: Implement closeAgent**

In `WorkspaceSessionsHolder`, after `openAgent`:

```swift
    /// Close one agent tab: terminate the PTY (a real close, not a hide)
    /// and drop the instance. Refused for the last remaining agent — the
    /// firstAgentTab fallback contract requires at least one. If the closed
    /// tab was selected, selection moves to the previous neighbor (or the
    /// next when the closed tab was first) — same rule as closeFile.
    func closeAgent(projectId: UUID, agentId: UUID) {
        guard let session = sessions[projectId], session.agents.count > 1,
              let index = session.agents.firstIndex(where: { $0.id == agentId }) else { return }

        let instance = session.agents.remove(at: index)
        instance.session.terminate()
        if session.selectedTab == .agent(agentId) {
            session.selectedTab = .agent(session.agents[max(0, index - 1)].id)
        }
    }
```

- [ ] **Step 4: Wire close buttons on the agent chips**

In `WorkspaceRootView.tabRow`, the agents `ForEach` chip gains a close closure — only when more than one agent is open:

```swift
                ForEach(session.agents) { agent in
                    WorkspaceTabChip(
                        icon: "sparkles",
                        title: agent.title,
                        isSelected: session.selectedTab == .agent(agent.id),
                        select: { session.selectedTab = .agent(agent.id) },
                        close: session.agents.count == 1 ? nil : {
                            holder.closeAgent(projectId: session.projectId, agentId: agent.id)
                        }
                    )
                }
```

- [ ] **Step 5: Run the suite**

Run: `pgrep -x xcodebuild || xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -5`
Expected: PASS, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift Devtail/Features/Workspace/Views/WorkspaceRootView.swift DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift
git commit -m "feat(workspace): closable agent tabs with last-tab protection"
```

---

### Task 5: Multi-agent quit accounting and project-close teardown

Task 1 already made `liveTerminalSessions()` and `close(projectId:)` iterate all agents — this task PROVES the multi-instance behavior with tests (quit correctness: an uncounted agent would survive app quit as an orphaned `claude` process).

**Files:**
- Test: `DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift`

**Interfaces:**
- Consumes: `openAgent(projectId:)`, `shutdownAll(deadline:completion:)`, `hasLiveSessions`, `close(projectId:)` (existing + Tasks 1/3).
- Produces: nothing new — regression coverage only.

- [ ] **Step 1: Write the tests (expected to pass — proving, not driving)**

Add to `WorkspaceSessionsHolderTests.swift`:

```swift
// MARK: - Multi-agent quit accounting

/// Every live agent counts: with two agents, one exiting must NOT flip
/// hasLiveSessions — only when both are gone.
@Test func hasLiveSessionsCountsEveryAgentInstance() throws {
    let (holder, _) = makeSUT()
    let session = holder.openSession(for: project("alpha"))
    let second = try #require(holder.openAgent(projectId: session.projectId))

    (session.agents[0].session as? MockTerminalSession)?.simulateExit(code: 0)
    #expect(holder.hasLiveSessions)

    (second.session as? MockTerminalSession)?.simulateExit(code: 0)
    #expect(!holder.hasLiveSessions)
}

/// Deferred quit: a second agent that never exits is a straggler and gets
/// force-killed at the deadline — it must not survive app quit.
@Test func shutdownAllWithDeadlineForceKillsSecondAgentStraggler() throws {
    var scheduled: [(delay: TimeInterval, block: @MainActor () -> Void)] = []
    let (holder, _) = makeSUT(schedule: { scheduled.append(($0, $1)) })
    let session = holder.openSession(for: project("alpha"))
    let second = try #require(holder.openAgent(projectId: session.projectId))
    let firstMock = try #require(session.agents[0].session as? MockTerminalSession)
    let secondMock = try #require(second.session as? MockTerminalSession)

    var completions = 0
    holder.shutdownAll(deadline: 2.0) { completions += 1 }

    // SIGTERM wave reached BOTH agents.
    #expect(firstMock.terminateCount >= 1)
    #expect(secondMock.terminateCount >= 1)

    firstMock.simulateExit(code: 0)
    #expect(completions == 0)

    scheduled[0].block()
    #expect(secondMock.forceKillCount == 1)
    #expect(completions == 1)
}

/// close(projectId:) terminates EVERY agent instance, not just the first.
@Test func closeTerminatesEveryAgentInstance() throws {
    let (holder, _) = makeSUT()
    let session = holder.openSession(for: project("alpha"))
    let second = try #require(holder.openAgent(projectId: session.projectId))
    let firstMock = try #require(session.agents[0].session as? MockTerminalSession)
    let secondMock = try #require(second.session as? MockTerminalSession)

    holder.close(projectId: session.projectId)

    #expect(firstMock.terminateCount == 1)
    #expect(secondMock.terminateCount == 1)
}
```

- [ ] **Step 2: Run the suite — all three must pass against the Task 1 implementation**

Run: `pgrep -x xcodebuild || xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -5`
Expected: PASS, 0 failures. If any of these three fails, the Task 1 iteration in `liveTerminalSessions()`/`close(projectId:)` is wrong — fix it there, not in the tests.

- [ ] **Step 3: Commit**

```bash
git add DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift
git commit -m "test(workspace): multi-agent quit accounting and close teardown"
```
