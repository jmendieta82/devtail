//
//  ProjectStoreWorkspacePaneTests.swift
//  DevtailTests
//
//  Unit tests for ProjectStore's WorkspacePane CRUD operations, layout
//  management (setLayout, assignPaneToSlot), and auto-seed behavior.
//  Uses mock repositories — no SwiftData container involved.
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
            workspacePaneRepository: paneRepo,
            vscodeLauncher: MockVSCodeLauncher(),
            browserLauncher: MockBrowserLauncher()
        )
        return (store, projectRepo, paneRepo)
    }

    // MARK: - addWorkspacePane

    @Test("addWorkspacePane delegates to repository on success")
    func addWorkspacePaneSuccess() {
        let (store, _, paneRepo) = makeStore()
        let project = Project(name: "Devtail", color: .green)

        store.addWorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "",
            to: project
        )

        #expect(paneRepo.createCallCount == 1)
        #expect(paneRepo.lastCreateLabel == "Main")
        #expect(paneRepo.lastCreateRelativeCwd == ".")
        #expect(paneRepo.lastCreateLayoutSlot == -1)
        #expect(store.lastError == nil)
    }

    @Test("addWorkspacePane with explicit layoutSlot passes it through")
    func addWorkspacePaneWithSlot() {
        let (store, _, paneRepo) = makeStore()
        let project = Project(name: "Devtail", color: .green)

        store.addWorkspacePane(
            label: "API",
            relativeCwd: "api",
            command: "",
            layoutSlot: 1,
            to: project
        )

        #expect(paneRepo.lastCreateLayoutSlot == 1)
    }

    @Test("addWorkspacePane captures error on failure — invalidLayoutSlot")
    func addWorkspacePaneError() {
        let (store, _, paneRepo) = makeStore()
        paneRepo.errorToThrow = WorkspacePaneError.invalidLayoutSlot
        let project = Project(name: "Devtail", color: .green)

        store.addWorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "",
            layoutSlot: -2,
            to: project
        )

        #expect(store.lastError as? WorkspacePaneError == .invalidLayoutSlot)
    }

    // MARK: - updateWorkspacePane

    @Test("updateWorkspacePane delegates and mutates all fields including stack and environment")
    func updateWorkspacePaneSuccess() {
        let (store, _, paneRepo) = makeStore()
        let project = Project(name: "Devtail", color: .green)
        let pane = WorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "",
            order: 0,
            layoutSlot: 0,
            project: project
        )

        store.updateWorkspacePane(
            pane,
            label: "API",
            relativeCwd: "api",
            command: "npm run dev",
            stack: "TypeScript",
            environment: .staging
        )

        #expect(paneRepo.updateCallCount == 1)
        #expect(pane.label == "API")
        #expect(pane.relativeCwd == "api")
        #expect(pane.command == "npm run dev")
        #expect(pane.stack == "TypeScript")
        #expect(pane.environment == .staging)
        #expect(store.lastError == nil)
    }

    // MARK: - environment field on the pane

    @Test("addWorkspacePane passes environment through to repository")
    func addWorkspacePanePassesEnvironment() {
        let (store, _, paneRepo) = makeStore()
        let project = Project(name: "Devtail", color: .green)

        store.addWorkspacePane(
            label: "API",
            relativeCwd: "api",
            command: "npm run dev",
            layoutSlot: 1,
            stack: "TypeScript",
            environment: .prod,
            to: project
        )

        #expect(paneRepo.lastCreateEnvironment == .prod)
    }

    @Test("addWorkspacePane defaults environment to nil when omitted")
    func addWorkspacePaneEnvironmentDefaultsToNil() {
        let (store, _, paneRepo) = makeStore()
        let project = Project(name: "Devtail", color: .green)

        store.addWorkspacePane(
            label: "logs",
            relativeCwd: "logs",
            command: "tail -f app.log",
            to: project
        )

        #expect(paneRepo.lastCreateEnvironment == nil)
    }

    @Test("updateWorkspacePane clears environment when nil is passed")
    func updateWorkspacePaneClearsEnvironment() {
        let (store, _, _) = makeStore()
        let project = Project(name: "Devtail", color: .green)
        let pane = WorkspacePane(
            label: "API",
            relativeCwd: "api",
            command: "",
            order: 0,
            layoutSlot: 0,
            environment: .prod,
            project: project
        )

        store.updateWorkspacePane(
            pane,
            label: "API",
            relativeCwd: "api",
            command: "",
            stack: nil,
            environment: nil
        )

        #expect(pane.environment == nil)
    }

    @Test("updateWorkspacePane captures error on failure")
    func updateWorkspacePaneError() {
        let (store, _, paneRepo) = makeStore()
        paneRepo.errorToThrow = WorkspacePaneError.invalidLabel
        let project = Project(name: "Devtail", color: .green)
        let pane = WorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "",
            order: 0,
            layoutSlot: 0,
            project: project
        )

        store.updateWorkspacePane(
            pane,
            label: "",
            relativeCwd: ".",
            command: "",
            stack: nil
        )

        #expect(store.lastError as? WorkspacePaneError == .invalidLabel)
    }

    // MARK: - deleteWorkspacePane

    @Test("deleteWorkspacePane delegates to repository and clears lastError")
    func deleteWorkspacePaneSuccess() {
        let (store, _, paneRepo) = makeStore()
        let project = Project(name: "Devtail", color: .green)
        let pane = WorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "",
            order: 0,
            layoutSlot: 0,
            project: project
        )

        store.deleteWorkspacePane(pane)

        #expect(paneRepo.deleteCallCount == 1)
        #expect(paneRepo.lastDeletedPane === pane)
        #expect(store.lastError == nil)
    }

    @Test("deleteWorkspacePane captures error on failure")
    func deleteWorkspacePaneError() {
        let (store, _, paneRepo) = makeStore()
        paneRepo.errorToThrow = WorkspacePaneError.invalidLabel
        let project = Project(name: "Devtail", color: .green)
        let pane = WorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "",
            order: 0,
            layoutSlot: 0,
            project: project
        )

        store.deleteWorkspacePane(pane)

        #expect(store.lastError as? WorkspacePaneError == .invalidLabel)
    }

    @Test("deleteWorkspacePane surfaces cannotDeleteLastPane from the repository")
    func deleteWorkspacePaneLastPaneRefused() {
        let (store, _, paneRepo) = makeStore()
        paneRepo.errorToThrow = WorkspacePaneError.cannotDeleteLastPane
        let project = Project(name: "Devtail", color: .green)
        let pane = WorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "",
            order: 0,
            layoutSlot: 0,
            project: project
        )

        store.deleteWorkspacePane(pane)

        #expect(store.lastError as? WorkspacePaneError == .cannotDeleteLastPane)
    }

    // MARK: - Root pane auto-seed

    @Test("createProject without directoryPath does NOT seed any pane")
    func createProjectWithoutDirectoryPathDoesNotSeedPane() {
        let (store, _, paneRepo) = makeStore()

        store.createProject(name: "Devtail")

        #expect(paneRepo.createCallCount == 0)
    }

    @Test("createProject with directoryPath seeds root pane with layoutSlot 0 and layout .full")
    func createProjectWithDirectoryPath() {
        let (store, projectRepo, paneRepo) = makeStore()

        store.createProject(name: "Devtail", directoryPath: "/Users/dev/devtail")

        #expect(projectRepo.updateCallCount == 1)
        #expect(store.projects.first?.directoryPath == "/Users/dev/devtail")
        #expect(store.projects.first?.layout == .full)
        #expect(paneRepo.createCallCount == 1)
        #expect(paneRepo.lastCreateLabel == "Devtail")
        #expect(paneRepo.lastCreateRelativeCwd == ".")
        #expect(paneRepo.lastCreateLayoutSlot == 0)
    }

    @Test("createProject without directoryPath does not call project repository update")
    func createProjectWithoutDirectoryPathSkipsUpdate() {
        let (store, projectRepo, _) = makeStore()

        store.createProject(name: "Devtail")

        #expect(projectRepo.updateCallCount == 0)
        #expect(store.projects.first?.directoryPath == "")
    }

    // MARK: - setLayout

    @Test("setLayout shrink — pane at excess slot moved to -1, others unchanged")
    func setLayoutShrink() {
        let (store, projectRepo, _) = makeStore()
        let project = Project(name: "P", color: .green)
        project.layout = .mainSideStack  // 3 slots

        let paneA = WorkspacePane(label: "A", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        let paneB = WorkspacePane(label: "B", relativeCwd: "api", command: "", order: 1, layoutSlot: 1, project: project)
        let paneC = WorkspacePane(label: "C", relativeCwd: "web", command: "", order: 2, layoutSlot: 2, project: project)
        project.workspacePanes = [paneA, paneB, paneC]
        projectRepo.projectsToReturn = [project]
        store.loadProjects()

        store.setLayout(for: project, layout: .halvesVertical)  // 2 slots

        #expect(project.layout == .halvesVertical)
        #expect(paneA.layoutSlot == 0)
        #expect(paneB.layoutSlot == 1)
        #expect(paneC.layoutSlot == -1)  // displaced
    }

    @Test("setLayout grow — existing panes are not affected")
    func setLayoutGrow() {
        let (store, projectRepo, _) = makeStore()
        let project = Project(name: "P", color: .green)
        project.layout = .halvesVertical  // 2 slots

        let paneA = WorkspacePane(label: "A", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        let paneB = WorkspacePane(label: "B", relativeCwd: "api", command: "", order: 1, layoutSlot: 1, project: project)
        project.workspacePanes = [paneA, paneB]
        projectRepo.projectsToReturn = [project]
        store.loadProjects()

        store.setLayout(for: project, layout: .mainSideStack)  // 3 slots

        #expect(project.layout == .mainSideStack)
        #expect(paneA.layoutSlot == 0)
        #expect(paneB.layoutSlot == 1)
    }

    @Test("setLayout same layout — no pane slot changes")
    func setLayoutSame() {
        let (store, projectRepo, _) = makeStore()
        let project = Project(name: "P", color: .green)
        project.layout = .halvesVertical

        let paneA = WorkspacePane(label: "A", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        let paneB = WorkspacePane(label: "B", relativeCwd: "api", command: "", order: 1, layoutSlot: 1, project: project)
        project.workspacePanes = [paneA, paneB]
        projectRepo.projectsToReturn = [project]
        store.loadProjects()

        store.setLayout(for: project, layout: .halvesVertical)

        #expect(paneA.layoutSlot == 0)
        #expect(paneB.layoutSlot == 1)
    }

    // MARK: - assignPaneToSlot

    @Test("assignPaneToSlot to empty slot — pane assigned, others unaffected")
    func assignPaneToEmptySlot() {
        let (store, projectRepo, _) = makeStore()
        let project = Project(name: "P", color: .green)
        project.layout = .halvesVertical

        let paneA = WorkspacePane(label: "A", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        let paneB = WorkspacePane(label: "B", relativeCwd: "api", command: "", order: 1, layoutSlot: -1, project: project)
        project.workspacePanes = [paneA, paneB]
        projectRepo.projectsToReturn = [project]
        store.loadProjects()

        store.assignPaneToSlot(pane: paneB, slot: 1)

        #expect(paneB.layoutSlot == 1)
        #expect(paneA.layoutSlot == 0)
        #expect(store.lastError == nil)
    }

    @Test("assignPaneToSlot displaces prior occupant to -1")
    func assignPaneToOccupiedSlot() {
        let (store, projectRepo, _) = makeStore()
        let project = Project(name: "P", color: .green)
        project.layout = .halvesVertical

        let paneA = WorkspacePane(label: "A", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        let paneB = WorkspacePane(label: "B", relativeCwd: "api", command: "", order: 1, layoutSlot: 1, project: project)
        let paneC = WorkspacePane(label: "C", relativeCwd: "web", command: "", order: 2, layoutSlot: -1, project: project)
        project.workspacePanes = [paneA, paneB, paneC]
        projectRepo.projectsToReturn = [project]
        store.loadProjects()

        store.assignPaneToSlot(pane: paneC, slot: 0)

        #expect(paneC.layoutSlot == 0)
        #expect(paneA.layoutSlot == -1)  // displaced
        #expect(paneB.layoutSlot == 1)   // unaffected
    }

    @Test("assignPaneToSlot out of range throws slotOutOfRange")
    func assignPaneToSlotOutOfRange() {
        let (store, projectRepo, _) = makeStore()
        let project = Project(name: "P", color: .green)
        project.layout = .halvesVertical  // 2 slots (0, 1)

        let pane = WorkspacePane(label: "A", relativeCwd: ".", command: "", order: 0, layoutSlot: -1, project: project)
        project.workspacePanes = [pane]
        projectRepo.projectsToReturn = [project]
        store.loadProjects()

        store.assignPaneToSlot(pane: pane, slot: 5)

        #expect(store.lastError as? ProjectLayoutError == .slotOutOfRange(slot: 5, max: 2))
    }

    @Test("assignPaneToSlot slot -1 is always accepted (unassign)")
    func assignPaneToSentinelSlot() {
        let (store, projectRepo, _) = makeStore()
        let project = Project(name: "P", color: .green)
        project.layout = .halvesVertical

        let pane = WorkspacePane(label: "A", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        project.workspacePanes = [pane]
        projectRepo.projectsToReturn = [project]
        store.loadProjects()

        store.assignPaneToSlot(pane: pane, slot: -1)

        #expect(pane.layoutSlot == -1)
        #expect(store.lastError == nil)
    }

    // MARK: - prepareLaunch
    //
    // Store-side launch prep only: stamps lastLaunchedAt and persists branch
    // state for drift detection. Process spawn and frontend browser opening
    // moved to ProcessSupervisor / WorkspaceSessionsHolder (see
    // ProcessSupervisorTests / WorkspaceSessionsHolderTests) — window
    // opening itself lives in the view layer via `openWindow`.

    @Test("prepareLaunch stamps lastLaunchedAt and clears lastError")
    func prepareLaunchStampsLastLaunchedAt() {
        let (store, _, _) = makeStore()
        let project = Project(name: "Devtail", color: .green)
        project.directoryPath = "/Users/dev/devtail"
        #expect(project.lastLaunchedAt == nil)

        store.prepareLaunch(for: project)

        #expect(project.lastLaunchedAt != nil)
        #expect(store.lastError == nil)
    }

    @Test("prepareLaunch is synchronous and idempotent across repeated calls")
    func prepareLaunchIsSynchronous() {
        let (store, _, _) = makeStore()
        let project = Project(name: "Devtail", color: .green)
        project.directoryPath = "/Users/dev/devtail"

        store.prepareLaunch(for: project)
        let first = project.lastLaunchedAt

        store.prepareLaunch(for: project)
        let second = project.lastLaunchedAt

        #expect(first != nil)
        #expect(second != nil)
        #expect(store.lastError == nil)
    }
}
