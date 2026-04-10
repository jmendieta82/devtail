//
//  ProjectStore.swift
//  Devtail
//
//  Observable state holder for the Context Switcher's project list.
//  Mediates between the repository (persistence) and future SwiftUI views.
//

import Foundation

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

    /// Toggled while a `launchWorkspace` call is in flight. Lets the UI
    /// show a "Launching..." state without owning the async lifecycle
    /// itself — the store manages on/off around the Task that actually
    /// calls the launcher.
    private(set) var isLaunchingWorkspace: Bool = false

    private let repository: any ProjectRepositoryProtocol
    private let quickLinkRepository: any QuickLinkRepositoryProtocol
    private let workspacePaneRepository: any WorkspacePaneRepositoryProtocol
    private let launcher: any WorkspaceLauncherProtocol

    init(
        repository: any ProjectRepositoryProtocol,
        quickLinkRepository: any QuickLinkRepositoryProtocol,
        workspacePaneRepository: any WorkspacePaneRepositoryProtocol,
        launcher: any WorkspaceLauncherProtocol
    ) {
        self.repository = repository
        self.quickLinkRepository = quickLinkRepository
        self.workspacePaneRepository = workspacePaneRepository
        self.launcher = launcher
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
        directoryPath: String = ""
    ) {
        do {
            let project = try repository.create(
                name: name,
                notes: notes,
                color: color
            )
            if !directoryPath.isEmpty {
                project.directoryPath = directoryPath
                project.layout = .full
                try repository.update(project)

                // Seed a root pane mirroring the directoryPath the user
                // just picked. The original Phase 2.5 decision was to
                // NOT seed any default pane, on the rationale that
                // panes should "point at real subfolders the user
                // intentionally picked". Real usage proved that
                // rationale was incomplete: the user already picks the
                // project root via NSOpenPanel when creating the
                // project, and forcing them to recreate that exact
                // path as a pane afterwards is duplicate intent, not
                // pure model. The pane below is named after the
                // project so a stack of Ghostty windows shouts which
                // project each one belongs to. We do NOT seed when
                // directoryPath is empty — that case is honest "no
                // root yet" and seeding a fake pane WOULD be a lie.
                _ = try? workspacePaneRepository.create(
                    label: name,
                    relativeCwd: ".",
                    command: "",
                    order: 0,
                    layoutSlot: 0,
                    stack: nil,
                    environment: nil,
                    project: project
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
        color: ProjectColor,
        directoryPath: String = ""
    ) {
        do {
            project.name = name
            project.notes = notes
            project.color = color
            project.directoryPath = directoryPath
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
        environment: ProjectEnvironment? = nil,
        to project: Project
    ) {
        do {
            _ = try workspacePaneRepository.create(
                label: label,
                relativeCwd: relativeCwd,
                command: command,
                order: 0, // repository computes actual order from existing panes
                layoutSlot: layoutSlot,
                stack: stack,
                environment: environment,
                project: project
            )
            if let idx = projects.firstIndex(where: { $0.id == project.id }) {
                projects[idx] = project
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    func updateWorkspacePane(
        _ pane: WorkspacePane,
        label: String,
        relativeCwd: String,
        command: String,
        stack: String?,
        environment: ProjectEnvironment? = nil
    ) {
        do {
            pane.label = label
            pane.relativeCwd = relativeCwd
            pane.command = command
            pane.stack = stack
            pane.environment = environment
            try workspacePaneRepository.update(pane)
            if let project = pane.project,
               let idx = projects.firstIndex(where: { $0.id == project.id }) {
                projects[idx] = project
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

    // MARK: - Workspace Launcher

    func launchWorkspace(for project: Project) {
        // Guard against double-taps: if a launch is already in flight,
        // ignore the new request. Without this the user could spawn
        // multiple Ghostty windows by mashing the button.
        guard !isLaunchingWorkspace else { return }

        let panes = project.workspacePanes.sorted { $0.order < $1.order }
        isLaunchingWorkspace = true
        Task {
            defer { isLaunchingWorkspace = false }
            do {
                try await launcher.launch(project: project, panes: panes)
                lastError = nil
            } catch {
                lastError = error
            }
        }
    }
}
