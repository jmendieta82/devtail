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
    /// Replaced wholesale on `restartInteractive` — a fresh PTY/session, not
    /// mutated in place. `fileprivate(set)` (not `private(set)`): the write
    /// happens from `WorkspaceSessionsHolder` below, a different type in the
    /// same file — `private` alone would not grant it access.
    fileprivate(set) var interactive: TerminalSession
    /// Set true when the interactive shell's process exits (e.g. `exit` typed
    /// at the prompt). No auto-respawn: a crashing shell must not loop: this
    /// only drives the dead-state UI affordance until the user restarts it.
    var interactiveExited = false
    /// Second first-class terminal session running the configured coding
    /// agent (e.g. `claude`). Same replace-wholesale-on-restart contract as
    /// `interactive` — `fileprivate(set)` for the same reason.
    fileprivate(set) var agent: TerminalSession
    /// Set true when the agent process exits. Mirrors `interactiveExited`;
    /// no auto-respawn here either.
    var agentExited = false
    /// Which center-column tab is showing: interactive terminal, a managed
    /// process's log, or a file viewer.
    var selectedTab: WorkspaceTab = .terminal
    /// Files open in the workspace (read-only viewer tabs).
    private(set) var openFiles: [OpenFile] = []
    /// Current git branch of the project root, detected once at session
    /// open. Nil when the root isn't a git repo (or metadata is unreadable).
    let currentBranch: String?
    /// Timestamp the workspace was opened — feeds the elapsed-time card via
    /// `WorkspaceSessionClock`. `Date()` is nonisolated, so it's safe as a
    /// default even though this class is `@MainActor` by default isolation.
    let openedAt: Date
    /// Lazy file tree for the project root, backing the file-tree column.
    /// Constructed here (not as a default param) — `FileManagerDirectoryLister()`
    /// is `@MainActor`-isolated under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
    /// and cannot be a default parameter value.
    let fileTree: FileTreeStore

    init(projectId: UUID, projectName: String, root: URL,
         supervisor: ProcessSupervisor, interactive: TerminalSession,
         agent: TerminalSession,
         currentBranch: String? = nil,
         openedAt: Date = Date()) {
        self.projectId = projectId
        self.projectName = projectName
        self.root = root
        self.supervisor = supervisor
        self.interactive = interactive
        self.agent = agent
        self.currentBranch = currentBranch
        self.openedAt = openedAt
        self.fileTree = FileTreeStore(root: root, lister: FileManagerDirectoryLister())
    }

    /// Open a file in the workspace (append to openFiles if not already open,
    /// and select it). Idempotent: calling again with the same path simply
    /// re-selects it.
    func openFile(at path: String) {
        if !openFiles.contains(where: { $0.path == path }) {
            openFiles.append(OpenFile(path: path))
        }
        selectedTab = .file(path)
    }

    /// Close a file in the workspace. If the closed file was selected,
    /// selects the previous neighbor (or next if closed file was first).
    /// If no files remain, selects the terminal tab. No-op if the path
    /// is not in openFiles.
    func closeFile(at path: String) {
        guard let index = openFiles.firstIndex(where: { $0.path == path }) else { return }
        openFiles.remove(at: index)
        guard selectedTab == .file(path) else { return }
        if openFiles.isEmpty {
            selectedTab = .terminal
        } else {
            selectedTab = .file(openFiles[max(0, index - 1)].path)
        }
    }
}

@Observable
final class WorkspaceSessionsHolder {
    private let engine: TerminalEngine
    private let browserLauncher: BrowserLauncherProtocol
    private let settings: AppSettings
    private(set) var sessions: [UUID: WorkspaceSession] = [:]

    init(engine: TerminalEngine, browserLauncher: BrowserLauncherProtocol, settings: AppSettings) {
        self.engine = engine
        self.browserLauncher = browserLauncher
        self.settings = settings
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

        // A runtime-blank setting must not silently spawn a plain shell in
        // the agent tab — sanitize and fall back to "claude".
        let command = settings.agentCommand.trimmingCharacters(in: .whitespaces)
        let agent = engine.makeSession(
            TerminalSessionConfig(command: command.isEmpty ? "claude" : command, cwd: root, readOnly: false, imagePaste: true)
        )
        agent.start()

        // Managed processes are configured (cards visible, stopped) but do
        // NOT auto-start — the user starts each one manually via its
        // card's play button (ProcessCardView).
        let branch = GitBranchDetector().detectBranch(in: root)

        let session = WorkspaceSession(
            projectId: project.id, projectName: project.name, root: root,
            supervisor: supervisor, interactive: interactive, agent: agent,
            currentBranch: branch
        )
        wireInteractiveExit(interactive, on: session)
        wireAgentExit(agent, on: session)
        sessions[project.id] = session
        return session
    }

    /// Wires `onExit` so a shell exit (e.g. typing `exit`) flips the
    /// dead-state flag. Session-identity guard (same lesson as
    /// ProcessSupervisor.start): captures both the WorkspaceSession and the
    /// TerminalSession weakly, and only flips the flag if `session.interactive`
    /// is STILL this exact TerminalSession instance — otherwise a stale exit
    /// from a since-replaced (restarted) session would re-flip the flag after
    /// the user already restarted the shell.
    private func wireInteractiveExit(_ terminal: TerminalSession, on session: WorkspaceSession) {
        terminal.onExit = { [weak session, weak terminal] _ in
            guard let session, let terminal, session.interactive === terminal else { return }
            session.interactiveExited = true
        }
    }

    /// Mirrors `wireInteractiveExit` for the agent session: same identity
    /// guard against stale exits from a since-replaced (restarted) agent.
    private func wireAgentExit(_ terminal: TerminalSession, on session: WorkspaceSession) {
        terminal.onExit = { [weak session, weak terminal] _ in
            guard let session, let terminal, session.agent === terminal else { return }
            session.agentExited = true
        }
    }

    /// User-initiated restart of the interactive shell after it exited. No
    /// automatic respawn anywhere else — a crashing shell must not loop.
    func restartInteractive(projectId: UUID) {
        guard let session = sessions[projectId] else { return }

        session.interactive.terminate()

        let fresh = engine.makeSession(
            TerminalSessionConfig(command: nil, cwd: session.root, readOnly: false)
        )
        fresh.start()
        session.interactive = fresh
        wireInteractiveExit(fresh, on: session)
        session.interactiveExited = false
    }

    /// User-initiated restart of the agent session after it exited. Mirrors
    /// `restartInteractive`: terminate the old session, spawn a fresh one
    /// with the (sanitized) configured command, re-wire, reset the flag.
    func restartAgent(projectId: UUID) {
        guard let session = sessions[projectId] else { return }

        session.agent.terminate()

        let command = settings.agentCommand.trimmingCharacters(in: .whitespaces)
        let fresh = engine.makeSession(
            TerminalSessionConfig(command: command.isEmpty ? "claude" : command, cwd: session.root, readOnly: false, imagePaste: true)
        )
        fresh.start()
        session.agent = fresh
        wireAgentExit(fresh, on: session)
        session.agentExited = false
    }

    func isOpen(_ projectId: UUID) -> Bool {
        sessions[projectId] != nil
    }

    /// Kill every process group of this workspace and drop the session.
    func close(projectId: UUID) {
        guard let session = sessions.removeValue(forKey: projectId) else { return }
        session.supervisor.shutdownAll()
        session.interactive.terminate()
        session.agent.terminate()
    }

    /// App-quit teardown: no orphans holding ports.
    func shutdownAll() {
        for id in Array(sessions.keys) { close(projectId: id) }
    }
}
