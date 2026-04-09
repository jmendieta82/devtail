//
//  ProjectStoreTests.swift
//  DevtailTests
//
//  Unit tests for ProjectStore against a fully controlled MockProjectRepository.
//  No SwiftData container is involved — these are pure state-machine tests.
//

import Testing
import Foundation
@testable import Devtail

@MainActor
@Suite("ProjectStore")
struct ProjectStoreTests {

    private func makeStore(
        projectRepo: MockProjectRepository = MockProjectRepository(),
        linkRepo: MockQuickLinkRepository = MockQuickLinkRepository(),
        paneRepo: MockWorkspacePaneRepository = MockWorkspacePaneRepository(),
        launcher: MockWorkspaceLauncher = MockWorkspaceLauncher()
    ) -> ProjectStore {
        ProjectStore(
            repository: projectRepo,
            quickLinkRepository: linkRepo,
            workspacePaneRepository: paneRepo,
            launcher: launcher
        )
    }

    // MARK: - Initial state

    @Test("initial state is empty with no error")
    func initialStateIsEmptyWithNoError() {
        let mock = MockProjectRepository()
        let store = makeStore(projectRepo: mock)

        #expect(store.projects.isEmpty)
        #expect(store.lastError == nil)
    }

    // MARK: - loadProjects

    @Test("loadProjects populates projects from repository")
    func loadProjectsPopulatesFromRepository() {
        let mock = MockProjectRepository()
        mock.projectsToReturn = [
            Project(name: "Alpha"),
            Project(name: "Beta")
        ]
        let store = makeStore(projectRepo: mock)

        store.loadProjects()

        #expect(store.projects.count == 2)
        #expect(store.lastError == nil)
    }

    @Test("loadProjects with empty repository leaves projects empty")
    func loadProjectsWithEmptyRepositoryLeavesProjectsEmpty() {
        let mock = MockProjectRepository()
        mock.projectsToReturn = []
        let store = makeStore(projectRepo: mock)

        store.loadProjects()

        #expect(store.projects.isEmpty)
        #expect(store.lastError == nil)
    }

    @Test("loadProjects on repository error captures lastError and leaves projects unchanged")
    func loadProjectsErrorCapturesLastError() {
        let mock = MockProjectRepository()
        mock.errorToThrow = ProjectError.invalidName
        let store = makeStore(projectRepo: mock)

        store.loadProjects()

        #expect(store.lastError != nil)
        #expect(store.projects.isEmpty)
    }

    // MARK: - createProject

    @Test("createProject appends the created project on success")
    func createProjectAppendsOnSuccess() {
        let mock = MockProjectRepository()
        let store = makeStore(projectRepo: mock)

        store.createProject(name: "Gamma")

        #expect(store.projects.count == 1)
        #expect(store.projects.first?.name == "Gamma")
        #expect(store.lastError == nil)
    }

    @Test("createProject on invalidName captures ProjectError.invalidName")
    func createProjectErrorCapturesProjectError() {
        let mock = MockProjectRepository()
        mock.errorToThrow = ProjectError.invalidName
        let store = makeStore(projectRepo: mock)

        store.createProject(name: "")

        #expect(store.lastError as? ProjectError == .invalidName)
        #expect(store.projects.isEmpty)
    }

    // MARK: - deleteProject

    @Test("deleteProject removes the project from projects on success")
    func deleteProjectRemovesOnSuccess() {
        let mock = MockProjectRepository()
        let seed = [
            Project(name: "Alpha"),
            Project(name: "Beta")
        ]
        mock.projectsToReturn = seed
        let store = makeStore(projectRepo: mock)
        store.loadProjects()

        let target = store.projects[0]
        store.deleteProject(target)

        #expect(store.projects.count == 1)
        #expect(store.projects.contains { $0.id == target.id } == false)
        #expect(store.lastError == nil)
    }

    @Test("deleteProject on repository error captures lastError and keeps projects unchanged")
    func deleteProjectErrorKeepsProjectsUnchanged() {
        let mock = MockProjectRepository()
        mock.projectsToReturn = [Project(name: "Alpha")]
        let store = makeStore(projectRepo: mock)
        store.loadProjects()
        let originalCount = store.projects.count

        mock.errorToThrow = ProjectError.invalidName
        store.deleteProject(store.projects[0])

        #expect(store.lastError != nil)
        #expect(store.projects.count == originalCount)
    }

    // MARK: - Error clearing

    @Test("lastError is cleared after a subsequent successful call")
    func lastErrorClearedAfterSuccess() {
        let mock = MockProjectRepository()
        mock.errorToThrow = ProjectError.invalidName
        let store = makeStore(projectRepo: mock)

        store.loadProjects()
        #expect(store.lastError != nil)

        mock.errorToThrow = nil
        mock.projectsToReturn = [Project(name: "Alpha")]
        store.loadProjects()

        #expect(store.lastError == nil)
        #expect(store.projects.count == 1)
    }

    // MARK: - createProject seeds default pane

    @Test("createProject seeds a default Main pane via workspacePaneRepository")
    func createProjectSeedsDefaultPane() {
        let projectRepo = MockProjectRepository()
        let paneRepo = MockWorkspacePaneRepository()
        let store = makeStore(projectRepo: projectRepo, paneRepo: paneRepo)

        store.createProject(name: "Devtail")

        #expect(paneRepo.createCallCount == 1)
        #expect(paneRepo.lastCreateLabel == "Main")
    }

    // MARK: - Delegation

    @Test("createProject delegates exactly once to repository")
    func createProjectDelegatesOnce() {
        let mock = MockProjectRepository()
        let store = makeStore(projectRepo: mock)

        store.createProject(name: "Delta")

        #expect(mock.createCallCount == 1)
    }

    // MARK: - createProject with full fields

    @Test("createProject passes color, environment, and stack to repository")
    func createProjectPassesAllFieldsToRepository() {
        let mock = MockProjectRepository()
        let store = makeStore(projectRepo: mock)

        store.createProject(
            name: "Devtail",
            notes: nil,
            color: .purple,
            environment: .prod,
            stack: "Swift"
        )

        #expect(mock.lastCreatedFields?.color == .purple)
        #expect(mock.lastCreatedFields?.environment == .prod)
        #expect(mock.lastCreatedFields?.stack == "Swift")
    }

    // MARK: - updateProject

    @Test("updateProject mutates fields and delegates to repository exactly once")
    func updateProjectMutatesFieldsAndDelegatesToRepository() {
        let mock = MockProjectRepository()
        let seed = Project(
            name: "Original",
            color: .gray,
            environment: .dev,
            stack: nil
        )
        mock.projectsToReturn = [seed]
        let store = makeStore(projectRepo: mock)
        store.loadProjects()

        let target = store.projects[0]
        store.updateProject(
            target,
            name: "Renamed",
            notes: nil,
            color: .blue,
            environment: .staging,
            stack: "TypeScript"
        )

        #expect(target.name == "Renamed")
        #expect(target.color == .blue)
        #expect(target.environment == .staging)
        #expect(target.stack == "TypeScript")
        #expect(mock.updateCallCount == 1)
        #expect(store.projects.count == 1)
        #expect(store.lastError == nil)
    }

    @Test("updateProject on repository error captures lastError")
    func updateProjectOnRepositoryErrorCapturesLastError() {
        let mock = MockProjectRepository()
        let seed = Project(name: "Original")
        mock.projectsToReturn = [seed]
        let store = makeStore(projectRepo: mock)
        store.loadProjects()

        mock.errorToThrow = ProjectError.invalidName
        store.updateProject(
            store.projects[0],
            name: "Renamed",
            color: .blue,
            environment: .dev,
            stack: nil
        )

        #expect(store.lastError != nil)
    }

    @Test("updateProject clears a previously captured lastError on success")
    func updateProjectClearsLastErrorOnSuccess() {
        let mock = MockProjectRepository()
        mock.errorToThrow = ProjectError.invalidName
        let store = makeStore(projectRepo: mock)
        store.loadProjects()
        #expect(store.lastError != nil)

        let project = Project(name: "Recovery")
        mock.errorToThrow = nil
        mock.projectsToReturn = [project]
        store.loadProjects()

        store.updateProject(
            store.projects[0],
            name: "Recovered",
            color: .green,
            environment: .prod,
            stack: nil
        )

        #expect(store.lastError == nil)
    }
}
