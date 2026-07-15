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
    /// Current git branch of the project root, detected once at session
    /// open. Nil when the root isn't a git repo (or metadata is unreadable).
    let currentBranch: String?
    /// Project quick links, order-sorted, snapshotted at session open.
    let quickLinks: [(title: String, url: String)]

    init(projectId: UUID, projectName: String, root: URL,
         supervisor: ProcessSupervisor, interactive: TerminalSession,
         currentBranch: String? = nil, quickLinks: [(title: String, url: String)] = []) {
        self.projectId = projectId
        self.projectName = projectName
        self.root = root
        self.supervisor = supervisor
        self.interactive = interactive
        self.selectedTab = nil
        self.currentBranch = currentBranch
        self.quickLinks = quickLinks
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

        let branch = GitBranchDetector().detectBranch(in: root)
        let links = project.quickLinks
            .sorted { $0.order < $1.order }
            .map { (title: $0.label, url: $0.url) }

        let session = WorkspaceSession(
            projectId: project.id, projectName: project.name, root: root,
            supervisor: supervisor, interactive: interactive,
            currentBranch: branch, quickLinks: links
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
