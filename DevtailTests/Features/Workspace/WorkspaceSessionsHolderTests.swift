//
//  WorkspaceSessionsHolderTests.swift
//  DevtailTests
//
//  TDD for WorkspaceSessionsHolder: app-level owner of live workspace
//  sessions, keyed by project id. Verifies idempotent open, root cwd wiring,
//  and that close/shutdownAll terminate every underlying terminal session.
//

import Foundation
import SwiftData
import Testing
@testable import Devtail

@MainActor
struct WorkspaceSessionsHolderTests {
    /// `agentCommand`, when non-nil, is pre-seeded into a fresh, uniquely
    /// named `UserDefaults` suite BEFORE `AppSettings` reads it — mirrors
    /// how a user-configured command would already be persisted at launch.
    /// `schedule` replaces the holder's quit-deadline scheduler (default: a
    /// no-op — nothing fires unless the test captures and fires it).
    private func makeSUT(
        agentCommand: String? = nil,
        schedule: @escaping (TimeInterval, @escaping @MainActor () -> Void) -> Void = { _, _ in }
    ) -> (WorkspaceSessionsHolder, MockTerminalEngine) {
        let defaults = UserDefaults(suiteName: "WorkspaceSessionsHolderTests-\(UUID().uuidString)")!
        if let agentCommand {
            defaults.set(agentCommand, forKey: "agentCommand")
        }
        let settings = AppSettings(defaults: defaults)
        let engine = MockTerminalEngine()
        let holder = WorkspaceSessionsHolder(
            engine: engine, browserLauncher: MockBrowserLauncher(), settings: settings,
            schedule: schedule
        )
        return (holder, engine)
    }

    /// In-memory ModelContainer so a `WorkspacePane` can be attached to a
    /// `Project` via the SwiftData relationship (`project.workspacePanes`)
    /// without crashing — a context-less `Project` cannot own relationship
    /// data. Mirrors the pattern in WorkspacePaneRepositoryTests.
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Project.self, QuickLink.self, WorkspacePane.self,
            configurations: config
        )
        return ModelContext(container)
    }

    /// `Project`'s designated init only takes name/notes/color — directoryPath
    /// is a separate mutable stored property (default ""), so it's set here.
    private func project(_ name: String) -> Project {
        let p = Project(name: name)
        p.directoryPath = "/tmp/\(name)"
        return p
    }

    @Test func openSessionSpawnsOnlyAgentAndIsIdempotent() {
        let (holder, engine) = makeSUT()
        let p = project("alpha")
        let s1 = holder.openSession(for: p)
        let s2 = holder.openSession(for: p)
        #expect(s1 === s2)
        // Only the agent is constant/auto-started now — the interactive
        // terminal is ephemeral (opened on demand via openInteractive).
        #expect(engine.configs.count { !$0.readOnly } == 1)
        let agent = engine.configs.first { !$0.readOnly }
        #expect(agent?.command != nil)
        #expect(agent?.cwd.path == "/tmp/alpha")
        #expect(holder.isOpen(p.id))
        #expect(s1.interactive == nil)
    }

    /// Managed processes are configured (cards visible, stopped) but must
    /// NOT auto-start on workspace open — the user starts them manually via
    /// each card's play button. Only the agent session is spawned
    /// automatically; the interactive terminal is ephemeral.
    @Test func openSessionConfiguresButDoesNotStartManagedProcesses() throws {
        let (holder, engine) = makeSUT()
        let context = try makeContext()
        let p = project("alpha")
        context.insert(p)
        let pane = WorkspacePane(label: "back", relativeCwd: "api", command: "npm run dev",
                                  order: 0, layoutSlot: 0, project: p)
        context.insert(pane)
        p.workspacePanes.append(pane)

        let session = holder.openSession(for: p)

        // Only the agent session is spawned. No session was created for the
        // managed process, and no interactive terminal either (ephemeral).
        #expect(engine.sessions.count == 1)
        #expect(session.supervisor.processes.count == 1)
        #expect(session.supervisor.processes[0].state == .stopped)
    }

    @Test func closeShutsDownProcessesAndAgentWithNoInteractiveOpen() throws {
        let (holder, engine) = makeSUT()
        let context = try makeContext()
        let p = project("alpha")
        context.insert(p)
        let pane = WorkspacePane(label: "back", relativeCwd: "api", command: "npm run dev",
                                  order: 0, layoutSlot: 0, project: p)
        context.insert(pane)
        p.workspacePanes.append(pane)

        _ = holder.openSession(for: p)
        // Managed processes are not auto-started: only the agent session
        // exists at this point (interactive is ephemeral, not yet opened).
        #expect(engine.sessions.count == 1)

        holder.close(projectId: p.id)
        #expect(!holder.isOpen(p.id))
        #expect(engine.sessions.count == 1)
        #expect(engine.sessions.allSatisfy { $0.terminateCount >= 1 })
    }

    /// Same teardown, but with an interactive session opened first — proves
    /// `close` still terminates it via the optional-chained call when present.
    @Test func closeShutsDownProcessesTerminalAndAgentWhenInteractiveIsOpen() throws {
        let (holder, engine) = makeSUT()
        let context = try makeContext()
        let p = project("alpha")
        context.insert(p)
        let pane = WorkspacePane(label: "back", relativeCwd: "api", command: "npm run dev",
                                  order: 0, layoutSlot: 0, project: p)
        context.insert(pane)
        p.workspacePanes.append(pane)

        _ = holder.openSession(for: p)
        holder.openInteractive(projectId: p.id)
        #expect(engine.sessions.count == 2)

        holder.close(projectId: p.id)
        #expect(!holder.isOpen(p.id))
        #expect(engine.sessions.count == 2)
        #expect(engine.sessions.allSatisfy { $0.terminateCount >= 1 })
    }

    @Test func shutdownAllClosesEveryOpenWorkspace() {
        let (holder, engine) = makeSUT()
        _ = holder.openSession(for: project("a"))
        _ = holder.openSession(for: project("b"))
        holder.shutdownAll()
        #expect(engine.sessions.allSatisfy { $0.terminateCount >= 1 })
    }

    // MARK: - currentBranch population

    /// Writes a `.git/HEAD` file with the given contents under `folder`.
    /// Mirrors the fixture pattern in GitBranchDetectorTests.
    private func makeGitDir(in folder: URL, head: String) throws {
        let gitDir = folder.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
        let headURL = gitDir.appendingPathComponent("HEAD")
        try head.data(using: .utf8)!.write(to: headURL)
    }

    @Test func openSessionDetectsCurrentBranchFromProjectRoot() throws {
        let (holder, _) = makeSUT()
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-workspace-session-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try makeGitDir(in: folder, head: "ref: refs/heads/main\n")

        let p = project("alpha")
        p.directoryPath = folder.path

        let session = holder.openSession(for: p)

        #expect(session.currentBranch == "main")
    }

    @Test func openSessionWithNoGitLeavesBranchNil() {
        let (holder, _) = makeSUT()
        let p = project("alpha")

        let session = holder.openSession(for: p)

        #expect(session.currentBranch == nil)
    }

    @Test func openSessionStampsOpenedAt() {
        let (holder, _) = makeSUT()
        let p = project("alpha")

        let session = holder.openSession(for: p)

        #expect(abs(session.openedAt.timeIntervalSinceNow) < 5)
    }

    @Test func openSessionStartsOnAgentTab() {
        let (holder, _) = makeSUT()
        let p = project("alpha")

        let session = holder.openSession(for: p)

        #expect(session.selectedTab == .agent)
    }

    // MARK: - Interactive shell (ephemeral: open/close on demand)

    @Test func openInteractiveSpawnsPlainShellSessionAtRoot() {
        let (holder, engine) = makeSUT()
        let p = project("alpha")
        let session = holder.openSession(for: p)

        holder.openInteractive(projectId: p.id)

        #expect(session.interactive != nil)
        let interactiveMock = session.interactive as? MockTerminalSession
        #expect(interactiveMock?.startCount == 1)
        let config = engine.configs.first { $0.command == nil }
        #expect(config?.readOnly == false)
        #expect(config?.cwd.path == "/tmp/alpha")
    }

    @Test func openInteractiveIsIdempotentWhenAlreadyLive() {
        let (holder, _) = makeSUT()
        let p = project("alpha")
        let session = holder.openSession(for: p)

        holder.openInteractive(projectId: p.id)
        let first = session.interactive as? MockTerminalSession

        holder.openInteractive(projectId: p.id)

        #expect(session.interactive === first)
        #expect(first?.startCount == 1)
    }

    @Test func closeInteractiveTerminatesNilsAndResetsFlag() {
        let (holder, _) = makeSUT()
        let p = project("alpha")
        let session = holder.openSession(for: p)
        holder.openInteractive(projectId: p.id)
        let mock = session.interactive as? MockTerminalSession
        session.selectedTab = .terminal

        holder.closeInteractive(projectId: p.id)

        #expect(mock?.terminateCount == 1)
        #expect(session.interactive == nil)
        #expect(session.interactiveExited == false)
        #expect(session.selectedTab == .agent)
    }

    @Test func closeInteractiveDoesNotChangeSelectionWhenAnotherTabIsSelected() {
        let (holder, _) = makeSUT()
        let p = project("alpha")
        let session = holder.openSession(for: p)
        holder.openInteractive(projectId: p.id)
        session.selectedTab = .agent

        holder.closeInteractive(projectId: p.id)

        #expect(session.selectedTab == .agent)
    }

    @Test func closeInteractiveWhenNoneOpenIsSafeNoOp() {
        let (holder, _) = makeSUT()
        let p = project("alpha")
        let session = holder.openSession(for: p)

        holder.closeInteractive(projectId: p.id)

        #expect(session.interactive == nil)
    }

    @Test func interactiveExitSetsInteractiveExitedFlag() throws {
        let (holder, _) = makeSUT()
        let p = project("alpha")
        let session = holder.openSession(for: p)
        holder.openInteractive(projectId: p.id)
        let interactiveMock = try #require(session.interactive as? MockTerminalSession)

        interactiveMock.simulateExit(code: 0)

        #expect(session.interactiveExited)
    }

    @Test func restartInteractiveCreatesFreshSessionResetsFlagAndTerminatesOld() throws {
        let (holder, engine) = makeSUT()
        let p = project("alpha")
        let session = holder.openSession(for: p)
        holder.openInteractive(projectId: p.id)
        let oldInteractive = session.interactive as! MockTerminalSession
        oldInteractive.simulateExit(code: 1)
        #expect(session.interactiveExited)

        holder.restartInteractive(projectId: p.id)

        #expect(!session.interactiveExited)
        #expect(oldInteractive.terminateCount >= 1)
        #expect(session.interactive !== oldInteractive)
        // A fresh non-readOnly session was spawned at the same root.
        let freshInteractive = session.interactive as! MockTerminalSession
        #expect(freshInteractive.startCount == 1)
        #expect(engine.configs.last?.readOnly == false)
        #expect(engine.configs.last?.cwd.path == "/tmp/alpha")
    }

    @Test func staleExitFromReplacedInteractiveSessionDoesNotReflipFlagAfterRestart() throws {
        let (holder, _) = makeSUT()
        let p = project("alpha")
        let session = holder.openSession(for: p)
        holder.openInteractive(projectId: p.id)
        let oldInteractive = session.interactive as! MockTerminalSession

        holder.restartInteractive(projectId: p.id)
        #expect(!session.interactiveExited)

        // The OLD (replaced) session's process dies late/async after restart.
        // Identity guard must prevent this stale callback from re-flipping
        // the flag — the current `session.interactive` is a different
        // instance now.
        oldInteractive.simulateExit(code: 1)

        #expect(!session.interactiveExited)
    }

    @Test func restartInteractiveWhenNoneOpenIsSafeNoOp() {
        let (holder, engine) = makeSUT()
        let p = project("alpha")
        let session = holder.openSession(for: p)

        holder.restartInteractive(projectId: p.id)

        #expect(session.interactive == nil)
        #expect(engine.sessions.count == 1) // only the agent
    }

    // MARK: - Agent session (first-class, mirrors interactive machinery)

    @Test func openSessionSpawnsAgentWithConfiguredCommand() {
        let (holder, engine) = makeSUT(agentCommand: "claude --continue")
        let session = holder.openSession(for: project("alpha"))
        let agentConfigs = engine.configs.filter { $0.command == "claude --continue" }
        #expect(agentConfigs.count == 1)
        #expect(agentConfigs[0].readOnly == false)
        #expect(session.agentExited == false)
    }

    @Test func openSessionSpawnsAgentWithDefaultClaude() {
        let (holder, engine) = makeSUT()
        _ = holder.openSession(for: project("alpha"))
        #expect(engine.configs.contains { $0.command == "claude" && !$0.readOnly })
    }

    @Test func agentExitSetsAgentExitedFlag() {
        let (holder, _) = makeSUT()
        let session = holder.openSession(for: project("alpha"))
        (session.agent as? MockTerminalSession)?.simulateExit(code: 0)
        #expect(session.agentExited == true)
        #expect(session.interactiveExited == false)
    }

    @Test func restartAgentCreatesFreshSessionAndResetsFlag() {
        let (holder, _) = makeSUT()
        let session = holder.openSession(for: project("alpha"))
        let old = session.agent as? MockTerminalSession
        old?.simulateExit(code: 1)
        holder.restartAgent(projectId: session.projectId)
        #expect(session.agent !== old)
        #expect(session.agentExited == false)
        #expect(old?.terminateCount == 1)
    }

    @Test func staleAgentExitAfterRestartDoesNotReflipFlag() {
        let (holder, _) = makeSUT()
        let session = holder.openSession(for: project("alpha"))
        let old = session.agent as? MockTerminalSession
        holder.restartAgent(projectId: session.projectId)
        old?.simulateExit(code: 1)
        #expect(session.agentExited == false)
    }

    @Test func closeTerminatesAgentSession() {
        let (holder, _) = makeSUT()
        let session = holder.openSession(for: project("alpha"))
        let agent = session.agent as? MockTerminalSession
        holder.close(projectId: session.projectId)
        #expect(agent?.terminateCount == 1)
    }

    // MARK: - Side panel state

    @Test func openSessionDefaultsToFilesSidePanel() {
        let (holder, _) = makeSUT()
        let session = holder.openSession(for: project("alpha"))
        #expect(session.sidePanel == .files)
    }

    /// The store just holds the optional — nil (collapsed) and any concrete
    /// panel both round-trip. The toggle decision itself lives in the view
    /// (ActivityBar), not here.
    @Test func sidePanelTogglesToNilWhenReselected() {
        let (holder, _) = makeSUT()
        let session = holder.openSession(for: project("alpha"))

        session.sidePanel = nil
        #expect(session.sidePanel == nil)

        session.sidePanel = .processes
        #expect(session.sidePanel == .processes)
    }

    @Test func dashboardCollapsedDefaultsFalse() {
        let (holder, _) = makeSUT()
        let session = holder.openSession(for: project("alpha"))
        #expect(session.dashboardCollapsed == false)

        session.dashboardCollapsed = true
        #expect(session.dashboardCollapsed == true)
    }

    // MARK: - Settings tab (ephemeral, opened from the activity rail gear)

    /// The settings tab is opened by direct assignment (activity rail gear
    /// button) rather than a holder method — this just proves the session's
    /// selection round-trips through it like any other tab and that closing
    /// it (mirrors the file viewer: nothing to preserve) returns to agent.
    @Test func selectedTabCanSwitchToSettingsAndBackToAgent() {
        let (holder, _) = makeSUT()
        let session = holder.openSession(for: project("alpha"))
        #expect(session.selectedTab == .agent)

        session.selectedTab = .settings
        #expect(session.selectedTab == .settings)

        session.selectedTab = .agent
        #expect(session.selectedTab == .agent)
    }

    // MARK: - Quit path: hasLiveSessions + shutdownAll(deadline:completion:)

    @Test func hasLiveSessionsReflectsAgentLifecycle() {
        let (holder, _) = makeSUT()
        #expect(!holder.hasLiveSessions)

        let session = holder.openSession(for: project("alpha"))
        #expect(holder.hasLiveSessions)

        (session.agent as? MockTerminalSession)?.simulateExit(code: 0)
        #expect(!holder.hasLiveSessions)
    }

    @Test func shutdownAllWithDeadlineCompletesImmediatelyWhenNothingLive() {
        let (holder, _) = makeSUT()
        let session = holder.openSession(for: project("alpha"))
        (session.agent as? MockTerminalSession)?.simulateExit(code: 0)

        var completions = 0
        holder.shutdownAll(deadline: 2.0) { completions += 1 }

        #expect(completions == 1)
        #expect(!holder.isOpen(session.projectId))
    }

    @Test func shutdownAllWithDeadlineCompletesEarlyWhenAllSessionsExit() throws {
        var scheduled: [(delay: TimeInterval, block: @MainActor () -> Void)] = []
        let (holder, _) = makeSUT(schedule: { scheduled.append(($0, $1)) })
        let session = holder.openSession(for: project("alpha"))
        holder.openInteractive(projectId: session.projectId)
        let agent = try #require(session.agent as? MockTerminalSession)
        let interactive = try #require(session.interactive as? MockTerminalSession)

        var completions = 0
        holder.shutdownAll(deadline: 2.0) { completions += 1 }

        // SIGTERM wave went out; completion waits for the exits.
        #expect(agent.terminateCount == 1)
        #expect(interactive.terminateCount == 1)
        #expect(completions == 0)

        agent.simulateExit(code: 0)
        #expect(completions == 0)
        interactive.simulateExit(code: 0)
        #expect(completions == 1)

        // A deadline firing after early completion must neither force-kill
        // nor double-complete.
        for entry in scheduled { entry.block() }
        #expect(completions == 1)
        #expect(agent.forceKillCount == 0)
        #expect(interactive.forceKillCount == 0)
    }

    @Test func shutdownAllWithDeadlineForceKillsStragglersAtDeadline() throws {
        var scheduled: [(delay: TimeInterval, block: @MainActor () -> Void)] = []
        let (holder, _) = makeSUT(schedule: { scheduled.append(($0, $1)) })
        let session = holder.openSession(for: project("alpha"))
        let agent = try #require(session.agent as? MockTerminalSession)

        var completions = 0
        holder.shutdownAll(deadline: 2.0) { completions += 1 }

        #expect(scheduled.count == 1)
        #expect(scheduled[0].delay == 2.0)
        #expect(completions == 0)

        scheduled[0].block()

        #expect(agent.forceKillCount == 1)
        #expect(completions == 1)
    }

    /// One session exits before the deadline, one never does: the deadline
    /// force-kills only the straggler and completes; the straggler's late
    /// exit must not re-complete.
    @Test func shutdownAllWithDeadlineCompletesExactlyOnce() throws {
        var scheduled: [(delay: TimeInterval, block: @MainActor () -> Void)] = []
        let (holder, _) = makeSUT(schedule: { scheduled.append(($0, $1)) })
        let session = holder.openSession(for: project("alpha"))
        holder.openInteractive(projectId: session.projectId)
        let agent = try #require(session.agent as? MockTerminalSession)
        let interactive = try #require(session.interactive as? MockTerminalSession)

        var completions = 0
        holder.shutdownAll(deadline: 2.0) { completions += 1 }
        interactive.simulateExit(code: 0)
        #expect(completions == 0)

        scheduled[0].block()
        #expect(agent.forceKillCount == 1)
        #expect(interactive.forceKillCount == 0)
        #expect(completions == 1)

        agent.simulateExit(code: nil)
        #expect(completions == 1)
    }

    @Test func runningManagedProcessCountsAsLiveAndIsForceKilledAtDeadline() throws {
        var scheduled: [(delay: TimeInterval, block: @MainActor () -> Void)] = []
        let (holder, _) = makeSUT(schedule: { scheduled.append(($0, $1)) })
        let context = try makeContext()
        let p = project("alpha")
        context.insert(p)
        let pane = WorkspacePane(label: "back", relativeCwd: "api", command: "npm run dev",
                                  order: 0, layoutSlot: 0, project: p)
        context.insert(pane)
        p.workspacePanes.append(pane)

        let session = holder.openSession(for: p)
        (session.agent as? MockTerminalSession)?.simulateExit(code: 0)
        #expect(!holder.hasLiveSessions)

        session.supervisor.startAll()
        #expect(holder.hasLiveSessions)
        let processMock = try #require(session.supervisor.processes[0].session as? MockTerminalSession)

        var completions = 0
        holder.shutdownAll(deadline: 2.0) { completions += 1 }
        #expect(completions == 0)

        scheduled[0].block()
        #expect(processMock.forceKillCount == 1)
        #expect(completions == 1)
    }

    /// terminateLater keeps the menu bar UI alive during the quit window: a
    /// Launch click after `shutdownAll(deadline:)` must not start a child
    /// process, and the inert session is still swept at the deadline.
    @Test func openSessionDuringShutdownIsInertAndSweptAtDeadline() throws {
        var scheduled: [(delay: TimeInterval, block: @MainActor () -> Void)] = []
        let (holder, _) = makeSUT(schedule: { scheduled.append(($0, $1)) })
        _ = holder.openSession(for: project("alpha"))

        var completions = 0
        holder.shutdownAll(deadline: 2.0) { completions += 1 }

        let late = holder.openSession(for: project("beta"))
        let lateAgent = try #require(late.agent as? MockTerminalSession)
        #expect(lateAgent.startCount == 0)

        scheduled[0].block()
        #expect(lateAgent.forceKillCount == 1)
        #expect(completions == 1)
    }
}
