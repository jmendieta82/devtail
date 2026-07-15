//
//  ProjectStore.swift
//  Devtail
//
//  Observable state holder for the Context Switcher's project list.
//  Mediates between the repository (persistence) and future SwiftUI views.
//

import Foundation

// MARK: - BranchChange

/// Describes a detected branch change between `lastKnownBranch` and the
/// current branch for a single pane. Used by the Resume flow to surface
/// a confirmation alert before relaunching.
struct BranchChange: Sendable {
    let paneLabel: String
    let from: String
    let to: String
}

// MARK: - ProjectLayoutError

enum ProjectLayoutError: Error, Equatable {
    case projectNotFound
    case paneNotFound
    case slotOutOfRange(slot: Int, max: Int)

    static func == (lhs: ProjectLayoutError, rhs: ProjectLayoutError) -> Bool {
        switch (lhs, rhs) {
        case (.projectNotFound, .projectNotFound): return true
        case (.paneNotFound, .paneNotFound): return true
        case (.slotOutOfRange(let s1, let m1), .slotOutOfRange(let s2, let m2)):
            return s1 == s2 && m1 == m2
        default: return false
        }
    }
}

// MARK: - ProjectStore

@MainActor
@Observable
final class ProjectStore {

    private(set) var projects: [Project] = []

    /// Generic `Error?` (not `ProjectError?`) because the repository may
    /// surface non-domain errors from SwiftData. Callers pattern-match via
    /// `lastError as? ProjectError` when they care about a specific case.
    /// See proposal §8.
    private(set) var lastError: Error?

    private let repository: any ProjectRepositoryProtocol
    private let quickLinkRepository: any QuickLinkRepositoryProtocol
    private let workspacePaneRepository: any WorkspacePaneRepositoryProtocol
    private let vscodeLauncher: any VSCodeLauncherProtocol
    private let browserLauncher: any BrowserLauncherProtocol

    init(
        repository: any ProjectRepositoryProtocol,
        quickLinkRepository: any QuickLinkRepositoryProtocol,
        workspacePaneRepository: any WorkspacePaneRepositoryProtocol,
        vscodeLauncher: any VSCodeLauncherProtocol,
        browserLauncher: any BrowserLauncherProtocol
    ) {
        self.repository = repository
        self.quickLinkRepository = quickLinkRepository
        self.workspacePaneRepository = workspacePaneRepository
        self.vscodeLauncher = vscodeLauncher
        self.browserLauncher = browserLauncher
    }

    func loadProjects() {
        do {
            projects = try repository.findAll()
            lastError = nil
        } catch {
            lastError = error
        }
    }

    func createProject(
        name: String,
        notes: String? = nil,
        color: ProjectColor = .gray,
        directoryPath: String = "",
        directoryBookmark: Data? = nil,
        launchTarget: LaunchTarget = .auto
    ) {
        do {
            let project = try repository.create(
                name: name,
                notes: notes,
                color: color
            )
            project.launchTarget = launchTarget
            if !directoryPath.isEmpty {
                project.directoryPath = directoryPath
                project.directoryBookmark = directoryBookmark
                project.layout = .full
                try repository.update(project)

                // Seed a root pane mirroring the directoryPath the user
                // just picked. The command starts empty — the agent
                // command (if any) is configured globally in Settings
                // and applied at spawn time, not baked into the seed.
                _ = try? workspacePaneRepository.create(
                    label: name,
                    relativeCwd: ".",
                    command: "",
                    order: 0,
                    layoutSlot: 0,
                    stack: nil,
                    isFrontend: false,
                    localhostUrl: nil,
                    environment: nil,
                    project: project
                )

                // Repository quick link is seeded from the pane's folder,
                // not here — see `seedRepositoryQuickLinkForPane(...)`
                // triggered on addWorkspacePane / updateWorkspacePane.
                // This way each pane contributes its remote (useful for
                // monorepos with subtree/submodule-sourced subfolders),
                // deduped by URL at the project level.
                seedRepositoryQuickLinkForPane(
                    project: project,
                    relativeCwd: "."
                )
            }
            projects.append(project)
            lastError = nil
        } catch {
            lastError = error
        }
    }

    func updateProject(
        _ project: Project,
        name: String,
        notes: String? = nil,
        color: ProjectColor = .gray,
        directoryPath: String = "",
        directoryBookmark: Data? = nil
    ) {
        do {
            project.name = name
            project.notes = notes
            project.color = color
            project.directoryPath = directoryPath
            // Only overwrite the stored bookmark when a fresh one was captured
            // (user re-picked the folder). Passing nil keeps the existing
            // bookmark intact — important for edit flows that don't touch
            // the directory field.
            if let directoryBookmark {
                project.directoryBookmark = directoryBookmark
            }
            try repository.update(project)

            // Force @Observable to detect the nested mutation by re-assigning
            // the array slot. Project is a reference type so the array still
            // holds the same instance; this is purely a notification trigger.
            if let idx = projects.firstIndex(where: { $0.id == project.id }) {
                projects[idx] = project
            }

            lastError = nil
        } catch {
            lastError = error
        }
    }

    func deleteProject(_ project: Project) {
        do {
            try repository.delete(project)
            projects.removeAll { $0.id == project.id }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    /// Detects the git remote of the pane's folder (project root joined
    /// with the pane's `relativeCwd`) and inserts a quick link pointing at
    /// the web URL, labeled by host (GitHub / GitLab / Bitbucket /
    /// Repository). Silent no-op when: the folder isn't a git repo, origin
    /// has no URL, the URL is unparseable, the project has no directory
    /// path, or the project already has a quick link with the same URL
    /// (dedup — matters for monorepos where multiple panes share origin).
    private func seedRepositoryQuickLinkForPane(project: Project, relativeCwd: String) {
        let root = project.directoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !root.isEmpty else { return }

        let rel = relativeCwd.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = URL(fileURLWithPath: root, isDirectory: true)
        let folderURL: URL = {
            if rel.isEmpty || rel == "." {
                return baseURL
            }
            let suffix = rel.hasPrefix("./") ? String(rel.dropFirst(2)) : rel
            return baseURL.appendingPathComponent(suffix, isDirectory: true)
        }()

        guard let remote = GitRemoteDetector().detectRemote(in: folderURL) else {
            return
        }
        let alreadyExists = project.quickLinks.contains { $0.url == remote.webURL }
        guard !alreadyExists else { return }
        _ = try? quickLinkRepository.create(
            label: remote.label,
            url: remote.webURL,
            project: project
        )
    }

    func addQuickLink(label: String, url: String, to project: Project) {
        do {
            _ = try quickLinkRepository.create(label: label, url: url, project: project)
            if let idx = projects.firstIndex(where: { $0.id == project.id }) {
                projects[idx] = project
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    func updateQuickLink(_ quickLink: QuickLink, label: String, url: String) {
        do {
            quickLink.label = label
            quickLink.url = url
            try quickLinkRepository.update(quickLink)
            if let project = quickLink.project,
               let idx = projects.firstIndex(where: { $0.id == project.id }) {
                projects[idx] = project
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    func deleteQuickLink(_ quickLink: QuickLink) {
        let project = quickLink.project
        do {
            try quickLinkRepository.delete(quickLink)
            if let project,
               let idx = projects.firstIndex(where: { $0.id == project.id }) {
                projects[idx] = project
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    // MARK: - WorkspacePane CRUD

    func addWorkspacePane(
        label: String,
        relativeCwd: String,
        command: String,
        layoutSlot: Int = -1,
        stack: String? = nil,
        isFrontend: Bool = false,
        localhostUrl: String? = nil,
        environment: ProjectEnvironment? = nil,
        to project: Project
    ) {
        do {
            let newPane = try workspacePaneRepository.create(
                label: label,
                relativeCwd: relativeCwd,
                command: command,
                order: 0, // repository computes actual order from existing panes
                layoutSlot: layoutSlot,
                stack: stack,
                isFrontend: isFrontend,
                localhostUrl: localhostUrl,
                environment: environment,
                project: project
            )

            // Auto-upgrade the layout to fit the new pane count, and auto-assign
            // the new pane to the first free slot of the upgraded layout.
            autoUpgradeLayoutAndAssign(newPane: newPane, in: project)

            // Try to derive a repository quick link from the pane's folder.
            // Deduped by URL so multiple panes pointing at the same repo
            // (monorepo subfolders) contribute a single link.
            seedRepositoryQuickLinkForPane(project: project, relativeCwd: relativeCwd)

            if let idx = projects.firstIndex(where: { $0.id == project.id }) {
                projects[idx] = project
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    /// Grows the project's layout to match the number of panes, up to the
    /// maximum (Quarters, 4 slots). Then assigns the newly created pane to
    /// the first available slot. Never downgrades — removing panes leaves
    /// the layout as-is.
    private func autoUpgradeLayoutAndAssign(newPane: WorkspacePane, in project: Project) {
        let paneCount = project.workspacePanes.count
        let targetLayout: WorkspaceLayout
        switch paneCount {
        case 0, 1: targetLayout = .full
        case 2:    targetLayout = .halvesVertical
        case 3:    targetLayout = .mainSideStack
        default:   targetLayout = .quarters
        }

        // Only upgrade if the target has more slots than the current layout.
        if targetLayout.slotCount > project.layout.slotCount {
            project.layout = targetLayout
        }

        // Assign the new pane to the first free slot, if any.
        let usedSlots = Set(
            project.workspacePanes
                .filter { $0.id != newPane.id && $0.layoutSlot >= 0 }
                .map(\.layoutSlot)
        )
        for slot in 0..<project.layout.slotCount where !usedSlots.contains(slot) {
            newPane.layoutSlot = slot
            break
        }
    }

    func updateWorkspacePane(
        _ pane: WorkspacePane,
        label: String,
        relativeCwd: String,
        command: String,
        stack: String?,
        isFrontend: Bool = false,
        localhostUrl: String? = nil,
        environment: ProjectEnvironment? = nil
    ) {
        do {
            pane.label = label
            pane.relativeCwd = relativeCwd
            pane.command = command
            pane.stack = stack
            pane.isFrontend = isFrontend
            pane.localhostUrl = isFrontend ? localhostUrl : nil
            pane.environment = environment
            try workspacePaneRepository.update(pane)
            if let project = pane.project {
                // If the pane now points at a different folder (or the
                // folder only recently became a git repo), try to surface
                // the remote as a quick link. Dedup by URL keeps this idempotent.
                seedRepositoryQuickLinkForPane(project: project, relativeCwd: relativeCwd)
                if let idx = projects.firstIndex(where: { $0.id == project.id }) {
                    projects[idx] = project
                }
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    func deleteWorkspacePane(_ pane: WorkspacePane) {
        let project = pane.project
        do {
            try workspacePaneRepository.delete(pane)
            if let project,
               let idx = projects.firstIndex(where: { $0.id == project.id }) {
                projects[idx] = project
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    // MARK: - Layout Management

    /// Changes the layout for a project, displacing any panes whose
    /// `layoutSlot` falls outside the new layout's valid range to -1
    /// (unassigned). No panes are deleted.
    func setLayout(for project: Project, layout newLayout: WorkspaceLayout) {
        do {
            project.layout = newLayout
            for pane in project.workspacePanes where pane.layoutSlot >= newLayout.slotCount {
                pane.layoutSlot = -1
                try workspacePaneRepository.update(pane)
            }
            try repository.update(project)
            if let idx = projects.firstIndex(where: { $0.id == project.id }) {
                projects[idx] = project
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    /// Assigns a pane to a specific slot within its project's layout.
    /// If another pane already occupies the target slot, it is displaced
    /// to -1 (unassigned). Validates that the slot is within the layout's
    /// valid range (0 ..< slotCount), or equals -1 (unassigned sentinel).
    func assignPaneToSlot(pane: WorkspacePane, slot: Int) {
        do {
            guard let project = pane.project else {
                throw ProjectLayoutError.paneNotFound
            }
            guard slot == -1 || slot < project.layout.slotCount else {
                throw ProjectLayoutError.slotOutOfRange(slot: slot, max: project.layout.slotCount)
            }
            if slot >= 0 {
                for other in project.workspacePanes where other.id != pane.id && other.layoutSlot == slot {
                    other.layoutSlot = -1
                    try workspacePaneRepository.update(other)
                }
            }
            pane.layoutSlot = slot
            try workspacePaneRepository.update(pane)
            if let idx = projects.firstIndex(where: { $0.id == project.id }) {
                projects[idx] = project
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    // MARK: - Browser Launcher (per-pane)

    /// Opens the pane's `localhostUrl` in the default browser. No-op when
    /// the pane is not marked frontend or has no/invalid URL — the launcher
    /// itself validates the scheme and skips silently. Exposed as an
    /// independent action so the user can re-open the tab without having
    /// to relaunch the whole workspace.
    func openBrowser(for pane: WorkspacePane) {
        guard pane.isFrontend else { return }
        let urlString = (pane.localhostUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty else { return }
        browserLauncher.open(urlString: urlString)
    }

    // MARK: - VSCode Launcher

    func openInVSCode(project: Project) {
        Task {
            do {
                try await vscodeLauncher.open(
                    directoryPath: project.directoryPath,
                    bookmark: project.directoryBookmark
                )
                lastError = nil
            } catch {
                lastError = error
            }
        }
    }

    // MARK: - Workspace Launcher

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

    /// Detects branch changes for each pane in `project` by comparing
    /// `pane.lastKnownBranch` against the current HEAD. Returns only the
    /// panes where a change is detected. Panes without a `stack` or
    /// `relativeCwd` that doesn't resolve to a git repo are silently skipped.
    ///
    /// Called synchronously from the UI layer before deciding whether to
    /// show the Resume confirmation alert. `GitBranchDetector` reads only
    /// a few bytes from `.git/HEAD` so this is safe to call on MainActor.
    func detectBranchChanges(for project: Project) -> [BranchChange] {
        guard !project.directoryPath.isEmpty else { return [] }
        let detector = GitBranchDetector()
        let root = URL(fileURLWithPath: project.directoryPath, isDirectory: true)

        return project.workspacePanes.compactMap { pane -> BranchChange? in
            guard let known = pane.lastKnownBranch, !known.isEmpty else { return nil }
            let folder = pane.relativeCwd.trimmingCharacters(in: .whitespacesAndNewlines)
            let target: URL = (folder.isEmpty || folder == ".")
                ? root
                : root.appendingPathComponent(
                    folder.hasPrefix("./") ? String(folder.dropFirst(2)) : folder,
                    isDirectory: true
                )
            guard let current = detector.detectBranch(in: target) else { return nil }
            guard current != known else { return nil }
            return BranchChange(paneLabel: pane.label, from: known, to: current)
        }
    }

    // MARK: - Private helpers

    /// After a successful launch, snapshot the current branch for every pane
    /// so the next Resume can detect drift. Silently skips panes without a
    /// detectable branch (non-git folders, missing .git/HEAD, etc.).
    private func persistBranches(for project: Project, panes: [WorkspacePane]) {
        guard !project.directoryPath.isEmpty else { return }
        let detector = GitBranchDetector()
        let root = URL(fileURLWithPath: project.directoryPath, isDirectory: true)
        var didChange = false

        for pane in panes {
            let folder = pane.relativeCwd.trimmingCharacters(in: .whitespacesAndNewlines)
            let target: URL = (folder.isEmpty || folder == ".")
                ? root
                : root.appendingPathComponent(
                    folder.hasPrefix("./") ? String(folder.dropFirst(2)) : folder,
                    isDirectory: true
                )
            if let branch = detector.detectBranch(in: target) {
                pane.lastKnownBranch = branch
                try? workspacePaneRepository.update(pane)
                didChange = true
            }
        }

        if didChange,
           let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = project
        }
    }
}
