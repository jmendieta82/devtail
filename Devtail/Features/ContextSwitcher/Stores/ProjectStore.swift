//
//  ProjectStore.swift
//  Devtail
//
//  Observable state holder for the Context Switcher's project list.
//  Mediates between the repository (persistence) and future SwiftUI views.
//

import Foundation

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
        environment: ProjectEnvironment = .dev,
        stack: String? = nil,
        directoryPath: String = ""
    ) {
        do {
            let project = try repository.create(
                name: name,
                notes: notes,
                color: color,
                environment: environment,
                stack: stack
            )
            if !directoryPath.isEmpty {
                project.directoryPath = directoryPath
                try repository.update(project)
            }
            // Seed a default "Main" pane for every new project.
            _ = try? workspacePaneRepository.create(
                label: "Main",
                relativeCwd: ".",
                command: "",
                order: 0,
                splitDirection: "none",
                project: project
            )
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
        environment: ProjectEnvironment,
        stack: String?,
        directoryPath: String = ""
    ) {
        do {
            project.name = name
            project.notes = notes
            project.color = color
            project.environment = environment
            project.stack = (stack?.isEmpty == true) ? nil : stack
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
        splitDirection: String,
        to project: Project
    ) {
        do {
            _ = try workspacePaneRepository.create(
                label: label,
                relativeCwd: relativeCwd,
                command: command,
                order: 0, // repository computes actual order from existing panes
                splitDirection: splitDirection,
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
        splitDirection: String
    ) {
        do {
            pane.label = label
            pane.relativeCwd = relativeCwd
            pane.command = command
            pane.splitDirection = splitDirection
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

    // MARK: - Workspace Launcher

    func launchWorkspace(for project: Project) {
        let panes = project.workspacePanes.sorted { $0.order < $1.order }
        Task {
            do {
                try await launcher.launch(project: project, panes: panes)
                lastError = nil
            } catch {
                lastError = error
            }
        }
    }
}
