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
import os.log

/// In-flight edit state for one open env file, keyed by path in
/// `WorkspaceSession.envDrafts`. Survives `EnvFileEditorView` unmount/remount
/// (tab switches) because it lives on the session, not on view-local
/// `@State` — the whole point of this type. `loadedText` and
/// `recordedModificationDate` are the values read from disk when the draft
/// was created (or last synced after a save/reload); `isDirty` compares
/// `text` against `loadedText`.
struct EnvDraft {
    var text: String
    var loadedText: String
    var recordedModificationDate: Date?

    var isDirty: Bool { text != loadedText }
}

@Observable
final class WorkspaceSession: Identifiable {
    let projectId: UUID
    let projectName: String
    let root: URL
    let supervisor: ProcessSupervisor
    /// Ephemeral: nil until `openInteractive` is called, terminated and reset
    /// to nil by `closeInteractive`. Unlike the agents, the interactive
    /// terminal is never auto-started — the user opens/closes it at will,
    /// and closing kills the session. Replaced wholesale on `restartInteractive` — a
    /// fresh PTY/session, not mutated in place. `fileprivate(set)` (not
    /// `private(set)`): the write happens from `WorkspaceSessionsHolder`
    /// below, a different type in the same file — `private` alone would not
    /// grant it access.
    fileprivate(set) var interactive: TerminalSession?
    /// Set true when the interactive shell's process exits (e.g. `exit` typed
    /// at the prompt). No auto-respawn: a crashing shell must not loop: this
    /// only drives the dead-state UI affordance until the user restarts it.
    var interactiveExited = false
    /// The Claude agent tabs, in tab-row order. Always at least one — the
    /// first is seeded at session open; the last one cannot be closed.
    /// Same replace-wholesale-on-restart contract per instance as
    /// `interactive` — `fileprivate(set)` for the same reason.
    fileprivate(set) var agents: [AgentInstance]
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
    /// The universal tab fallback: every "go back to the agent" path
    /// (closing files/ephemeral tabs, dismissing settings) lands on the
    /// FIRST agent tab. Safe unconditionally — agents is never empty.
    var firstAgentTab: WorkspaceTab { .agent(agents[0].id) }
    /// Which center-column tab is showing. The agent tabs are the only
    /// constant ones, so the first agent is the default — assigned in init
    /// (the id doesn't exist at declaration time).
    var selectedTab: WorkspaceTab
    /// Files open in the workspace (read-only viewer tabs).
    private(set) var openFiles: [OpenFile] = []
    /// In-flight edit state for open env files, keyed by path. This is the
    /// single source of truth for both draft text and dirty state — it
    /// lives on the session (not view-local `@State`) so it survives
    /// `EnvFileEditorView` unmount/remount across tab switches, and so
    /// "Save and close" can act on it even when the editor isn't mounted.
    private(set) var envDrafts: [String: EnvDraft] = [:]
    /// Set by `saveAndCloseFile` when it hits an mtime conflict, alongside
    /// (not instead of) selecting the file's tab: `selectedTab` alone doesn't
    /// tell `EnvFileEditorView` *why* it was selected, so a fresh mount can't
    /// distinguish "user clicked the tab" from "conflict re-selected me" and
    /// would never show the alert. `EnvFileEditorView` consumes this via
    /// `consumeEnvConflict(for:)` on mount (or `.onChange` if already
    /// mounted) to decide whether to raise its conflict alert.
    private(set) var envConflictPath: String?
    /// Current git branch of the project root, detected once at session
    /// open. Nil when the root isn't a git repo (or metadata is unreadable).
    let currentBranch: String?
    /// Enriched git status (branch count, dirty state, ahead/behind),
    /// loaded asynchronously after the session is created — shelling out to
    /// `git` is I/O and must not block session creation. Nil until the
    /// first load completes (or if it fails / the root isn't a git repo).
    /// `var` and observable so the branch card updates when it arrives, and
    /// so a manual refresh can replace it in place.
    var gitStatus: GitStatus?
    /// Timestamp the workspace was opened — feeds the elapsed-time card via
    /// `WorkspaceSessionClock`. `Date()` is nonisolated, so it's safe as a
    /// default even though this class is `@MainActor` by default isolation.
    let openedAt: Date
    /// Lazy file tree for the project root, backing the file-tree column.
    let fileTree: FileTreeStore
    /// File-name search over the project root, backing the search field in
    /// the files side panel. The walk itself runs off the main actor — see
    /// `FileSearchWalker.search`.
    let fileSearch: FileSearchStore
    /// Task board for this project's .devtail/tasks.md — loaded lazily by
    /// the tasks side panel, not at session creation.
    let taskBoard: TaskBoardStore
    /// Which side panel view is showing: files or processes. `nil` means
    /// collapsed — the activity rail stays visible, but the panel itself
    /// (and its divider) is hidden. VS Code-style toggle: reselecting the
    /// active rail icon collapses it; any rail icon re-opens.
    var sidePanel: SidePanelView? = .files
    /// Whether the right-hand project dashboard column is collapsed to a
    /// slim chevron strip. Independent of `sidePanel` — the two panels
    /// collapse separately.
    var dashboardCollapsed = false
    /// Injected git status reader — real `GitStatusReader()` in production,
    /// a fake in tests. Lets `refreshGitStatus()` be exercised without
    /// shelling out to a real `git` process.
    private let gitStatusReader: GitStatusReading
    /// Handle to the in-flight `refreshGitStatus()` task, if any. Cancelled
    /// before starting a new refresh and on `close(projectId:)` teardown —
    /// otherwise a stale refresh from a closed (or since-reopened) session
    /// could assign `gitStatus` after the session is gone.
    private var gitStatusTask: Task<Void, Never>?
    /// Claude Code project introspection (skills/agents/commands/MCP
    /// servers/token usage), loaded asynchronously after the session is
    /// created — reading `.claude/` config and transcripts is disk I/O and
    /// must not block session creation. Nil until the first load completes.
    /// `var` and observable so the Claude card updates when it arrives, and
    /// so a manual refresh can replace it in place.
    var claudeInfo: ClaudeIntrospection?
    /// Injected Claude introspector — real `ClaudeProjectIntrospector()` in
    /// production, a fake in tests. Lets `refreshClaudeInfo()` be exercised
    /// without touching the real filesystem.
    private let claudeIntrospector: ClaudeIntrospecting
    /// Handle to the in-flight `refreshClaudeInfo()` task, if any. Cancelled
    /// before starting a new refresh and on `close(projectId:)` teardown —
    /// same rationale as `gitStatusTask`.
    private var claudeInfoTask: Task<Void, Never>?

    init(projectId: UUID, projectName: String, root: URL,
         supervisor: ProcessSupervisor,
         agent: AgentInstance,
         currentBranch: String? = nil,
         openedAt: Date = Date(),
         gitStatusReader: GitStatusReading = GitStatusReader(),
         claudeIntrospector: ClaudeIntrospecting = ClaudeProjectIntrospector()) {
        self.projectId = projectId
        self.projectName = projectName
        self.root = root
        self.supervisor = supervisor
        self.agents = [agent]
        self.selectedTab = .agent(agent.id)
        self.currentBranch = currentBranch
        self.openedAt = openedAt
        self.fileTree = FileTreeStore(root: root, lister: FileManagerDirectoryLister())
        self.fileSearch = FileSearchStore(root: root, walker: FileSearchWalker(lister: FileManagerDirectoryLister()))
        self.taskBoard = TaskBoardStore(root: root)
        self.gitStatusReader = gitStatusReader
        self.claudeIntrospector = claudeIntrospector
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
    /// If no files remain, selects the agent tab (the terminal tab may not
    /// exist anymore — it's ephemeral). No-op if the path is not in openFiles.
    func closeFile(at path: String) {
        guard let index = openFiles.firstIndex(where: { $0.path == path }) else { return }
        openFiles.remove(at: index)
        clearDraft(for: path)
        guard selectedTab == .file(path) else { return }
        if openFiles.isEmpty {
            selectedTab = firstAgentTab
        } else {
            selectedTab = .file(openFiles[max(0, index - 1)].path)
        }
    }

    /// Whether `path` currently has unsaved edits. Derives from the draft
    /// (if one exists) rather than a separate tracked set — one source of
    /// truth, so a stuck-dirty chip with no draft behind it is structurally
    /// impossible.
    func isDirty(path: String) -> Bool {
        envDrafts[path]?.isDirty ?? false
    }

    /// The current draft for `path`, if one has been created.
    func draft(for path: String) -> EnvDraft? {
        envDrafts[path]
    }

    /// Creates the draft for `path` if one doesn't already exist yet — used
    /// by `EnvFileEditorView` on (re)mount. If a draft already exists (e.g.
    /// the tab was switched away and back), it is left untouched: that's the
    /// survival behavior this type exists for.
    func createDraftIfNeeded(for path: String, loadedText: String, recordedModificationDate: Date?) {
        guard envDrafts[path] == nil else { return }
        envDrafts[path] = EnvDraft(text: loadedText, loadedText: loadedText, recordedModificationDate: recordedModificationDate)
    }

    /// Overwrites the whole draft for `path` — used after a successful save
    /// (loadedText/recordedModificationDate advance to the just-written
    /// state) and after an explicit reload from disk.
    func setDraft(_ draft: EnvDraft, for path: String) {
        envDrafts[path] = draft
    }

    /// Updates only the in-progress text for `path`, called on every
    /// keystroke from the bound `TextEditor`. No-op if there is no draft yet
    /// (shouldn't happen in practice — the editor creates one on mount).
    func updateDraft(text: String, for path: String) {
        guard envDrafts[path] != nil else { return }
        envDrafts[path]?.text = text
    }

    /// Drops the draft for `path` entirely — called on close.
    func clearDraft(for path: String) {
        envDrafts.removeValue(forKey: path)
    }

    /// Consumes the pending env conflict signal for `path`: if it matches,
    /// clears it and returns true (the caller should surface its conflict
    /// alert); otherwise leaves it untouched and returns false. One-shot by
    /// design — a second mount/onChange firing for the same path must not
    /// re-show the alert.
    func consumeEnvConflict(for path: String) -> Bool {
        guard envConflictPath == path else { return false }
        envConflictPath = nil
        return true
    }

    /// Session-level "Save and close", usable even when the file's editor
    /// view isn't mounted (e.g. the tab was switched away from). Saves
    /// straight from the stored draft via `EnvFileSaver` — no dependency on
    /// a mounted view's closure. On success, clears the draft and closes the
    /// tab. On an mtime conflict, does NOT silently overwrite: instead it
    /// selects the file's tab so the editor mounts and can show its own
    /// conflict alert, and the tab stays open.
    func saveAndCloseFile(at path: String) {
        guard let draft = envDrafts[path] else {
            closeFile(at: path)
            return
        }
        if let recorded = draft.recordedModificationDate,
           EnvFileSaver.hasConflict(path: path, recordedModificationDate: recorded) {
            envConflictPath = path
            selectedTab = .file(path)
            return
        }
        do {
            try EnvFileSaver.save(text: draft.text, to: path)
            closeFile(at: path)
        } catch {
            Log.files.error("Env save failed at \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            selectedTab = .file(path)
        }
    }

    /// Loads (or reloads) the enriched git status for this session's root
    /// and assigns it on the main actor. Called once at session open and
    /// again on user-initiated refresh (`branchSection`'s refresh button).
    /// `GitStatusReader` runs off the main actor internally, so this hop is
    /// the only main-actor work here.
    ///
    /// The previous in-flight refresh (if any) is cancelled before starting
    /// a new one, and the new task's handle is stored so `close(projectId:)`
    /// can cancel it too — otherwise a stale refresh could assign
    /// `gitStatus` after the session was torn down or superseded. The task
    /// checks `Task.isCancelled` after the `await` and bails before
    /// assigning if cancellation happened while the read was in flight.
    func refreshGitStatus() {
        gitStatusTask?.cancel()
        gitStatusTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let status = await self.gitStatusReader.status(in: self.root)
            guard !Task.isCancelled else { return }
            self.gitStatus = status
        }
    }

    /// Cancels the in-flight git status refresh, if any. Called from
    /// `WorkspaceSessionsHolder.close(projectId:)` alongside the other
    /// teardown steps.
    func cancelGitStatusRefresh() {
        gitStatusTask?.cancel()
        gitStatusTask = nil
    }

    /// Loads (or reloads) the Claude Code project introspection for this
    /// session's root and assigns it on the main actor. Called once at
    /// session open and again on user-initiated refresh (the Claude card's
    /// refresh button). Mirrors `refreshGitStatus()` exactly: the previous
    /// in-flight refresh (if any) is cancelled before starting a new one,
    /// the new task's handle is stored so `close(projectId:)` can cancel it
    /// too, and the task checks `Task.isCancelled` after the `await` before
    /// assigning.
    func refreshClaudeInfo() {
        claudeInfoTask?.cancel()
        claudeInfoTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let home = FileManager.default.homeDirectoryForCurrentUser
            let info = await self.claudeIntrospector.introspect(projectRoot: self.root, home: home)
            guard !Task.isCancelled else { return }
            self.claudeInfo = info
        }
    }

    /// Cancels the in-flight Claude info refresh, if any. Called from
    /// `WorkspaceSessionsHolder.close(projectId:)` alongside the other
    /// teardown steps.
    func cancelClaudeInfoRefresh() {
        claudeInfoTask?.cancel()
        claudeInfoTask = nil
    }
}

@Observable
final class WorkspaceSessionsHolder {
    private let engine: TerminalEngine
    private let browserLauncher: BrowserLauncherProtocol
    private let settings: AppSettings
    /// Deferred main-actor execution for the quit deadline — same injection
    /// shape as `ProcessTeardown.schedule`, so tests control time.
    private let schedule: (TimeInterval, @escaping @MainActor () -> Void) -> Void
    private(set) var sessions: [UUID: WorkspaceSession] = [:]
    /// Latched by the quit-path teardown: with `.terminateLater` the menu bar
    /// UI stays interactive until the deadline, so `openSession` must not
    /// spawn a child the already-sent SIGTERM wave can no longer see.
    private var isShuttingDown = false

    init(engine: TerminalEngine, browserLauncher: BrowserLauncherProtocol, settings: AppSettings,
         schedule: @escaping (TimeInterval, @escaping @MainActor () -> Void) -> Void = { delay, block in
             DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                 MainActor.assumeIsolated(block)
             }
         }) {
        self.engine = engine
        self.browserLauncher = browserLauncher
        self.settings = settings
        self.schedule = schedule
    }

    /// Create (or return the existing) live session for a project: only the
    /// agent is constant/auto-started. The interactive terminal is ephemeral
    /// (see `openInteractive`) and managed processes are configured but not
    /// started.
    func openSession(for project: Project) -> WorkspaceSession {
        if let existing = sessions[project.id] { return existing }

        let root = URL(fileURLWithPath: project.directoryPath, isDirectory: true)
        let supervisor = ProcessSupervisor(engine: engine, browserLauncher: browserLauncher)
        supervisor.configure(panes: project.workspacePanes.sorted { $0.order < $1.order }, root: root)

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

        // Managed processes are configured (cards visible, stopped) but do
        // NOT auto-start — the user starts each one manually via its
        // card's play button (ProcessCardView).
        let branch = GitBranchDetector().detectBranch(in: root)

        let session = WorkspaceSession(
            projectId: project.id, projectName: project.name, root: root,
            supervisor: supervisor, agent: agentInstance,
            currentBranch: branch
        )
        wireAgentExit(agentTerminal, on: agentInstance)
        sessions[project.id] = session
        // Inert during shutdown: the refreshes spawn work that outlives quit.
        guard !isShuttingDown else { return session }
        session.refreshGitStatus()
        session.refreshClaudeInfo()
        return session
    }

    /// Open the interactive shell tab on demand: idempotent when a live
    /// session already exists (no-op), otherwise spawns a fresh plain shell
    /// at the project root. The terminal is never auto-started — this is the
    /// only way it comes to life.
    func openInteractive(projectId: UUID) {
        guard let session = sessions[projectId] else { return }
        guard session.interactive == nil else { return }

        let interactive = engine.makeSession(
            TerminalSessionConfig(command: nil, cwd: session.root, readOnly: false)
        )
        interactive.start()
        session.interactive = interactive
        wireInteractiveExit(interactive, on: session)
        session.interactiveExited = false
    }

    /// Close the interactive shell tab: terminates the underlying session
    /// (killing the PTY — this is a real close, not a hide) and drops it.
    /// If the terminal tab was selected, falls back to the agent tab (the
    /// terminal tab may not exist anymore).
    func closeInteractive(projectId: UUID) {
        guard let session = sessions[projectId] else { return }
        session.interactive?.terminate()
        session.interactive = nil
        session.interactiveExited = false
        if session.selectedTab == .terminal {
            session.selectedTab = session.firstAgentTab
        }
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

    /// User-initiated restart of the interactive shell after it exited. Only
    /// acts when an interactive session currently exists — restart is not a
    /// way to open one from scratch, that's `openInteractive`'s job. No
    /// automatic respawn anywhere else — a crashing shell must not loop.
    func restartInteractive(projectId: UUID) {
        guard let session = sessions[projectId], let current = session.interactive else { return }

        current.terminate()

        let fresh = engine.makeSession(
            TerminalSessionConfig(command: nil, cwd: session.root, readOnly: false)
        )
        fresh.start()
        session.interactive = fresh
        wireInteractiveExit(fresh, on: session)
        session.interactiveExited = false
    }

    /// Mirrors `wireInteractiveExit` per agent instance: same identity guard
    /// against stale exits from a since-replaced (restarted) session.
    private func wireAgentExit(_ terminal: TerminalSession, on instance: AgentInstance) {
        terminal.onExit = { [weak instance, weak terminal] _ in
            guard let instance, let terminal, instance.session === terminal else { return }
            instance.exited = true
        }
    }

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

        guard !isShuttingDown else { return }

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
            // `index` is the pre-removal position; `agents` has just shrunk
            // by exactly one element. For index >= 1, index - 1 is still a
            // valid post-removal position (the new previous neighbor); for
            // index == 0 (closed tab was first), max(0, -1) == 0 selects the
            // new first element. Do not change this arithmetic without
            // re-verifying both cases.
            session.selectedTab = .agent(session.agents[max(0, index - 1)].id)
        }
    }

    func isOpen(_ projectId: UUID) -> Bool {
        sessions[projectId] != nil
    }

    /// Kill every process group of this workspace and drop the session.
    func close(projectId: UUID) {
        guard let session = sessions.removeValue(forKey: projectId) else { return }
        session.supervisor.shutdownAll()
        session.interactive?.terminate()
        for instance in session.agents { instance.session.terminate() }
        session.cancelGitStatusRefresh()
        session.cancelClaudeInfoRefresh()
        session.taskBoard.cancel()
        session.fileSearch.cancelSearch()
    }

    /// App-quit teardown: no orphans holding ports.
    func shutdownAll() {
        for id in Array(sessions.keys) { close(projectId: id) }
    }

    /// True while any workspace still has a terminal child presumed running:
    /// a non-exited agent, a live interactive shell, or a managed process in
    /// `.running`/`.starting`. Drives the quit decision — nothing live means
    /// the app may terminate immediately.
    var hasLiveSessions: Bool {
        !liveTerminalSessions().isEmpty
    }

    private func liveTerminalSessions() -> [TerminalSession] {
        var live: [TerminalSession] = []
        for session in sessions.values {
            for instance in session.agents where !instance.exited {
                live.append(instance.session)
            }
            if let interactive = session.interactive, !session.interactiveExited {
                live.append(interactive)
            }
            for process in session.supervisor.processes
            where process.state == .running || process.state == .starting {
                if let processSession = process.session {
                    live.append(processSession)
                }
            }
        }
        return live
    }

    /// Quit-path teardown: the SIGTERM wave is exactly the parameterless
    /// `shutdownAll()`; completion fires early when every live session's
    /// child exits, or at `deadline` after force-SIGKILLing stragglers.
    /// SIGKILL cannot be ignored, so completing right after delivery is safe
    /// — the kernel reparents and reaps, no wait needed. `completion` runs
    /// exactly once, on the main actor.
    func shutdownAll(deadline: TimeInterval, completion: @escaping @MainActor () -> Void) {
        isShuttingDown = true
        let live = liveTerminalSessions()
        guard !live.isEmpty else {
            shutdownAll()
            completion()
            return
        }
        Log.lifecycle.info("Deferred quit started: \(live.count, privacy: .public) live session(s), deadline \(deadline, privacy: .public)s")

        var outstanding = Set(live.map { ObjectIdentifier($0) })
        var completed = false
        let finish: @MainActor () -> Void = {
            guard !completed else { return }
            completed = true
            completion()
        }

        // Chain — don't replace — each session's onExit: the existing handler
        // (supervisor state guard, dead-agent flags) still runs first, then
        // the quit tracker counts down.
        for terminal in live {
            let id = ObjectIdentifier(terminal)
            let previous = terminal.onExit
            terminal.onExit = { code in
                previous?(code)
                outstanding.remove(id)
                if outstanding.isEmpty {
                    Log.lifecycle.info("Deferred quit: all sessions exited before the deadline")
                    finish()
                }
            }
        }

        shutdownAll()

        // `live` is captured strongly on purpose: `shutdownAll()` above drops
        // the holder's references, and a straggler must still be reachable
        // for the force-kill at the deadline.
        schedule(deadline) { [weak self] in
            guard !completed else { return }
            let stragglers = live.filter { outstanding.contains(ObjectIdentifier($0)) }
            // Fresh re-read: a session that raced in during the terminateLater
            // window is not in the entry snapshot but must not survive quit.
            let entryIds = Set(live.map { ObjectIdentifier($0) })
            let raced = (self?.liveTerminalSessions() ?? []).filter { !entryIds.contains(ObjectIdentifier($0)) }
            Log.lifecycle.info("Deferred quit: deadline reached, force-killing \(stragglers.count + raced.count, privacy: .public) straggler(s)")
            for terminal in stragglers + raced { terminal.forceKill() }
            finish()
        }
    }
}
