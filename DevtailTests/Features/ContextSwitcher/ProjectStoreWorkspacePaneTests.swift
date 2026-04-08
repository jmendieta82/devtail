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

    private func makeStore() -> (ProjectStore, MockProjectRepository, MockWorkspacePaneRepository) {
        let projectRepo = MockProjectRepository()
        let linkRepo = MockQuickLinkRepository()
        let paneRepo = MockWorkspacePaneRepository()
        let store = ProjectStore(
            repository: projectRepo,
            quickLinkRepository: linkRepo,
            workspacePaneRepository: paneRepo
        )
        return (store, projectRepo, paneRepo)
    }

    // MARK: - addWorkspacePane

    @Test("addWorkspacePane delegates to repository on success")
    func addWorkspacePaneSuccess() {
        let (store, _, paneRepo) = makeStore()
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
        let (store, _, paneRepo) = makeStore()
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
        let (store, _, paneRepo) = makeStore()
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
        let (store, _, paneRepo) = makeStore()
        paneRepo.errorToThrow = WorkspacePaneError.invalidLabel
        let project = Project(name: "Devtail", color: .green, environment: .dev)
        let pane = WorkspacePane(label: "Main", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)

        store.updateWorkspacePane(pane, label: "", relativeCwd: ".", command: "", splitDirection: "none")

        #expect(store.lastError as? WorkspacePaneError == .invalidLabel)
    }

    // MARK: - deleteWorkspacePane

    @Test("deleteWorkspacePane delegates to repository and clears lastError")
    func deleteWorkspacePaneSuccess() {
        let (store, _, paneRepo) = makeStore()
        let project = Project(name: "Devtail", color: .green, environment: .dev)
        let pane = WorkspacePane(label: "Main", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)

        store.deleteWorkspacePane(pane)

        #expect(paneRepo.deleteCallCount == 1)
        #expect(paneRepo.lastDeletedPane === pane)
        #expect(store.lastError == nil)
    }

    @Test("deleteWorkspacePane captures error on failure")
    func deleteWorkspacePaneError() {
        let (store, _, paneRepo) = makeStore()
        paneRepo.errorToThrow = WorkspacePaneError.invalidLabel
        let project = Project(name: "Devtail", color: .green, environment: .dev)
        let pane = WorkspacePane(label: "Main", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)

        store.deleteWorkspacePane(pane)

        #expect(store.lastError as? WorkspacePaneError == .invalidLabel)
    }

    // MARK: - createProject seeds default pane

    @Test("createProject seeds default Main pane via workspacePaneRepository")
    func createProjectSeedsDefaultPane() {
        let (store, _, paneRepo) = makeStore()

        store.createProject(name: "Devtail")

        #expect(paneRepo.createCallCount == 1)
        #expect(paneRepo.lastCreateLabel == "Main")
        #expect(paneRepo.lastCreateRelativeCwd == ".")
        #expect(paneRepo.lastCreateCommand == "")
        #expect(paneRepo.lastCreateSplitDirection == "none")
    }

    @Test("createProject with directoryPath assigns it to project.directoryPath")
    func createProjectWithDirectoryPath() {
        let (store, projectRepo, _) = makeStore()

        store.createProject(name: "Devtail", directoryPath: "/Users/dev/devtail")

        // Verify that update was called on the project repository to persist directoryPath
        #expect(projectRepo.updateCallCount == 1)
        #expect(store.projects.first?.directoryPath == "/Users/dev/devtail")
    }

    @Test("createProject without directoryPath does not call project repository update")
    func createProjectWithoutDirectoryPathSkipsUpdate() {
        let (store, projectRepo, _) = makeStore()

        store.createProject(name: "Devtail")

        #expect(projectRepo.updateCallCount == 0)
        #expect(store.projects.first?.directoryPath == "")
    }
}
