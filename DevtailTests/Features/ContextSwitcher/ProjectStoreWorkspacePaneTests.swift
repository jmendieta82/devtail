//
//  ProjectStoreWorkspacePaneTests.swift
//  DevtailTests
//
//  Unit tests for ProjectStore's WorkspacePane CRUD operations using mock
//  repositories. No SwiftData container involved.
//

import Testing
import Foundation
@testable import Devtail

@MainActor
@Suite("ProjectStore — WorkspacePane operations")
struct ProjectStoreWorkspacePaneTests {

    private func makeStore() -> (ProjectStore, MockProjectRepository, MockWorkspacePaneRepository, MockWorkspaceLauncher) {
        let projectRepo = MockProjectRepository()
        let linkRepo = MockQuickLinkRepository()
        let paneRepo = MockWorkspacePaneRepository()
        let launcher = MockWorkspaceLauncher()
        let store = ProjectStore(
            repository: projectRepo,
            quickLinkRepository: linkRepo,
            workspacePaneRepository: paneRepo,
            launcher: launcher
        )
        return (store, projectRepo, paneRepo, launcher)
    }

    // MARK: - addWorkspacePane

    @Test("addWorkspacePane delegates to repository on success")
    func addWorkspacePaneSuccess() {
        let (store, _, paneRepo, _) = makeStore()
        let project = Project(name: "Devtail", color: .green, environment: .dev)

        store.addWorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "",
            splitDirection: "none",
            to: project
        )

        #expect(paneRepo.createCallCount == 1)
        #expect(paneRepo.lastCreateLabel == "Main")
        #expect(paneRepo.lastCreateRelativeCwd == ".")
        #expect(paneRepo.lastCreateSplitDirection == "none")
        #expect(store.lastError == nil)
    }

    @Test("addWorkspacePane captures error on failure — invalidSplitDirection")
    func addWorkspacePaneError() {
        let (store, _, paneRepo, _) = makeStore()
        paneRepo.errorToThrow = WorkspacePaneError.invalidSplitDirection
        let project = Project(name: "Devtail", color: .green, environment: .dev)

        store.addWorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "",
            splitDirection: "diagonal",
            to: project
        )

        #expect(store.lastError as? WorkspacePaneError == .invalidSplitDirection)
    }

    // MARK: - updateWorkspacePane

    @Test("updateWorkspacePane delegates and mutates all four fields")
    func updateWorkspacePaneSuccess() {
        let (store, _, paneRepo, _) = makeStore()
        let project = Project(name: "Devtail", color: .green, environment: .dev)
        let pane = WorkspacePane(label: "Main", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)

        store.updateWorkspacePane(pane, label: "API", relativeCwd: "api", command: "npm run dev", splitDirection: "right")

        #expect(paneRepo.updateCallCount == 1)
        #expect(pane.label == "API")
        #expect(pane.relativeCwd == "api")
        #expect(pane.command == "npm run dev")
        #expect(pane.splitDirection == "right")
        #expect(store.lastError == nil)
    }

    @Test("updateWorkspacePane captures error on failure")
    func updateWorkspacePaneError() {
        let (store, _, paneRepo, _) = makeStore()
        paneRepo.errorToThrow = WorkspacePaneError.invalidLabel
        let project = Project(name: "Devtail", color: .green, environment: .dev)
        let pane = WorkspacePane(label: "Main", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)

        store.updateWorkspacePane(pane, label: "", relativeCwd: ".", command: "", splitDirection: "none")

        #expect(store.lastError as? WorkspacePaneError == .invalidLabel)
    }

    // MARK: - deleteWorkspacePane

    @Test("deleteWorkspacePane delegates to repository and clears lastError")
    func deleteWorkspacePaneSuccess() {
        let (store, _, paneRepo, _) = makeStore()
        let project = Project(name: "Devtail", color: .green, environment: .dev)
        let pane = WorkspacePane(label: "Main", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)

        store.deleteWorkspacePane(pane)

        #expect(paneRepo.deleteCallCount == 1)
        #expect(paneRepo.lastDeletedPane === pane)
        #expect(store.lastError == nil)
    }

    @Test("deleteWorkspacePane captures error on failure")
    func deleteWorkspacePaneError() {
        let (store, _, paneRepo, _) = makeStore()
        paneRepo.errorToThrow = WorkspacePaneError.invalidLabel
        let project = Project(name: "Devtail", color: .green, environment: .dev)
        let pane = WorkspacePane(label: "Main", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)

        store.deleteWorkspacePane(pane)

        #expect(store.lastError as? WorkspacePaneError == .invalidLabel)
    }

    // MARK: - createProject seeds default pane

    @Test("createProject seeds default Main pane via workspacePaneRepository")
    func createProjectSeedsDefaultPane() {
        let (store, _, paneRepo, _) = makeStore()

        store.createProject(name: "Devtail")

        #expect(paneRepo.createCallCount == 1)
        #expect(paneRepo.lastCreateLabel == "Main")
        #expect(paneRepo.lastCreateRelativeCwd == ".")
        #expect(paneRepo.lastCreateCommand == "")
        #expect(paneRepo.lastCreateSplitDirection == "none")
    }

    @Test("createProject with directoryPath assigns it to project.directoryPath")
    func createProjectWithDirectoryPath() {
        let (store, projectRepo, _, _) = makeStore()

        store.createProject(name: "Devtail", directoryPath: "/Users/dev/devtail")

        // Verify that update was called on the project repository to persist directoryPath
        #expect(projectRepo.updateCallCount == 1)
        #expect(store.projects.first?.directoryPath == "/Users/dev/devtail")
    }

    @Test("createProject without directoryPath does not call project repository update")
    func createProjectWithoutDirectoryPathSkipsUpdate() {
        let (store, projectRepo, _, _) = makeStore()

        store.createProject(name: "Devtail")

        #expect(projectRepo.updateCallCount == 0)
        #expect(store.projects.first?.directoryPath == "")
    }

    // MARK: - launchWorkspace

    @Test("launchWorkspace delegates to launcher with sorted panes")
    func launchWorkspaceDelegates() async {
        let (store, _, _, launcher) = makeStore()
        let project = Project(name: "Devtail", color: .green, environment: .dev)
        project.directoryPath = "/Users/dev/devtail"
        let pane1 = WorkspacePane(
            label: "Main", relativeCwd: ".", command: "claude",
            order: 0, splitDirection: "none", project: project
        )
        let pane2 = WorkspacePane(
            label: "Front", relativeCwd: "./frontend", command: "ng serve",
            order: 1, splitDirection: "right", project: project
        )
        project.workspacePanes = [pane2, pane1]  // unsorted on purpose

        store.launchWorkspace(for: project)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(launcher.launchCallCount == 1)
        #expect(launcher.lastLaunchedProject === project)
        #expect(launcher.lastLaunchedPanes.count == 2)
        #expect(launcher.lastLaunchedPanes[0].order == 0)
        #expect(launcher.lastLaunchedPanes[1].order == 1)
        #expect(store.lastError == nil)
    }

    @Test("launchWorkspace sets lastError on launcher failure")
    func launchWorkspaceFailure() async {
        let (store, _, _, launcher) = makeStore()
        launcher.errorToThrow = WorkspaceLauncherError.ghosttyNotInstalled
        let project = Project(name: "Devtail", color: .green, environment: .dev)
        project.directoryPath = "/Users/dev/devtail"

        store.launchWorkspace(for: project)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(
            store.lastError as? WorkspaceLauncherError == .ghosttyNotInstalled
        )
    }
}
