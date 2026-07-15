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
    private func makeSUT(agentCommand: String? = nil) -> (WorkspaceSessionsHolder, MockTerminalEngine) {
        let defaults = UserDefaults(suiteName: "WorkspaceSessionsHolderTests-\(UUID().uuidString)")!
        if let agentCommand {
            defaults.set(agentCommand, forKey: "agentCommand")
        }
        let settings = AppSettings(defaults: defaults)
        let engine = MockTerminalEngine()
        let holder = WorkspaceSessionsHolder(engine: engine, browserLauncher: MockBrowserLauncher(), settings: settings)
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

    @Test func openSessionSpawnsInteractiveTerminalAtRootAndIsIdempotent() {
        let (holder, engine) = makeSUT()
        let p = project("alpha")
        let s1 = holder.openSession(for: p)
        let s2 = holder.openSession(for: p)
        #expect(s1 === s2)
        // Exactly two non-readOnly sessions per workspace: the interactive
        // terminal (nil command) and the agent (configured command).
        #expect(engine.configs.count { !$0.readOnly } == 2)
        let interactive = engine.configs.first { !$0.readOnly && $0.command == nil }
        #expect(interactive?.command == nil)
        #expect(interactive?.cwd.path == "/tmp/alpha")
        #expect(holder.isOpen(p.id))
    }

    /// Managed processes are configured (cards visible, stopped) but must
    /// NOT auto-start on workspace open — the user starts them manually via
    /// each card's play button. Only the interactive terminal and the agent
    /// session are spawned automatically.
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

        // Only the interactive terminal + agent session are spawned. No
        // session was created for the managed process.
        #expect(engine.sessions.count == 2)
        #expect(session.supervisor.processes.count == 1)
        #expect(session.supervisor.processes[0].state == .stopped)
    }

    @Test func closeShutsDownProcessesAndTerminal() throws {
        let (holder, engine) = makeSUT()
        let context = try makeContext()
        let p = project("alpha")
        context.insert(p)
        let pane = WorkspacePane(label: "back", relativeCwd: "api", command: "npm run dev",
                                  order: 0, layoutSlot: 0, project: p)
        context.insert(pane)
        p.workspacePanes.append(pane)

        _ = holder.openSession(for: p)
        // Managed processes are not auto-started: only the interactive
        // terminal + agent session exist at this point.
        #expect(engine.sessions.count == 2)

        holder.close(projectId: p.id)
        #expect(!holder.isOpen(p.id))
        // Proves the holder propagates teardown through the supervisor to
        // every underlying session, not just the interactive terminal.
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

    @Test func openSessionStartsOnTerminalTab() {
        let (holder, _) = makeSUT()
        let p = project("alpha")

        let session = holder.openSession(for: p)

        #expect(session.selectedTab == .terminal)
    }

    // MARK: - Interactive shell exit / restart (no auto-respawn)

    @Test func interactiveExitSetsInteractiveExitedFlag() throws {
        let (holder, _) = makeSUT()
        let p = project("alpha")
        let session = holder.openSession(for: p)
        let interactiveMock = try #require(session.interactive as? MockTerminalSession)

        interactiveMock.simulateExit(code: 0)

        #expect(session.interactiveExited)
    }

    @Test func restartInteractiveCreatesFreshSessionResetsFlagAndTerminatesOld() throws {
        let (holder, engine) = makeSUT()
        let p = project("alpha")
        let session = holder.openSession(for: p)
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
}
