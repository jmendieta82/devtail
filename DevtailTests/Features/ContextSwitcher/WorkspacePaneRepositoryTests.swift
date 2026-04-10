//
//  WorkspacePaneRepositoryTests.swift
//  DevtailTests
//
//  Tests for WorkspacePaneRepository CRUD using an in-memory ModelContainer.
//

import Testing
import Foundation
import SwiftData
@testable import Devtail

@MainActor
@Suite("WorkspacePaneRepository")
struct WorkspacePaneRepositoryTests {
    let container: ModelContainer
    let context: ModelContext
    let projectRepo: ProjectRepository
    let paneRepo: WorkspacePaneRepository

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Project.self, QuickLink.self, WorkspacePane.self,
            configurations: config
        )
        context = ModelContext(container)
        projectRepo = ProjectRepository(context: context)
        paneRepo = WorkspacePaneRepository(context: context)
    }

    private func makeProject() throws -> Project {
        try projectRepo.create(name: "Devtail")
    }

    // MARK: - create

    @Test("create persists a pane with computed order 0 for the first pane")
    func createFirstPane() throws {
        let project = try makeProject()
        let pane = try paneRepo.create(
            label: "Main",
            relativeCwd: ".",
            command: "",
            order: 0,
            layoutSlot: 0,
            project: project
        )
        #expect(pane.label == "Main")
        #expect(pane.relativeCwd == ".")
        #expect(pane.order == 0)
        #expect(pane.layoutSlot == 0)
        #expect(pane.project?.id == project.id)
    }

    @Test("create assigns incremental order regardless of passed order param")
    func createAssignsIncrementalOrder() throws {
        let project = try makeProject()
        let a = try paneRepo.create(label: "A", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        let b = try paneRepo.create(label: "B", relativeCwd: "api", command: "", order: 0, layoutSlot: 1, project: project)
        let c = try paneRepo.create(label: "C", relativeCwd: "web", command: "", order: 0, layoutSlot: 2, project: project)
        #expect(a.order == 0)
        #expect(b.order == 1)
        #expect(c.order == 2)
    }

    @Test("create throws invalidLabel for empty label")
    func createInvalidLabel() throws {
        let project = try makeProject()
        #expect(throws: WorkspacePaneError.invalidLabel) {
            try paneRepo.create(label: "   ", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        }
    }

    @Test("create throws invalidRelativeCwd for empty cwd")
    func createInvalidRelativeCwd() throws {
        let project = try makeProject()
        #expect(throws: WorkspacePaneError.invalidRelativeCwd) {
            try paneRepo.create(label: "Main", relativeCwd: "  ", command: "", order: 0, layoutSlot: 0, project: project)
        }
    }

    @Test("create throws invalidLayoutSlot for slot below -1")
    func createInvalidLayoutSlot() throws {
        let project = try makeProject()
        #expect(throws: WorkspacePaneError.invalidLayoutSlot) {
            try paneRepo.create(label: "Main", relativeCwd: ".", command: "", order: 0, layoutSlot: -2, project: project)
        }
    }

    @Test("create accepts -1 as the unassigned sentinel")
    func createAcceptsSentinelSlot() throws {
        let project = try makeProject()
        #expect(throws: Never.self) {
            try paneRepo.create(label: "A", relativeCwd: ".", command: "", order: 0, layoutSlot: -1, project: project)
        }
    }

    @Test("create accepts non-negative slot values")
    func createAcceptsPositiveSlots() throws {
        let project = try makeProject()
        #expect(throws: Never.self) {
            try paneRepo.create(label: "A", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        }
        #expect(throws: Never.self) {
            try paneRepo.create(label: "B", relativeCwd: ".", command: "", order: 0, layoutSlot: 3, project: project)
        }
    }

    @Test("create allows empty command without throwing")
    func createAllowsEmptyCommand() throws {
        let project = try makeProject()
        #expect(throws: Never.self) {
            try paneRepo.create(label: "Main", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        }
    }

    // MARK: - findByProject

    @Test("findByProject returns panes sorted by order ascending")
    func findByProjectSorted() throws {
        let project = try makeProject()
        _ = try paneRepo.create(label: "A", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        _ = try paneRepo.create(label: "B", relativeCwd: ".", command: "", order: 0, layoutSlot: 1, project: project)
        _ = try paneRepo.create(label: "C", relativeCwd: ".", command: "", order: 0, layoutSlot: 2, project: project)
        let result = try paneRepo.findByProject(project)
        #expect(result.map(\.order) == [0, 1, 2])
    }

    @Test("findByProject returns empty array for project with no panes")
    func findByProjectEmpty() throws {
        let project = try makeProject()
        let result = try paneRepo.findByProject(project)
        #expect(result.isEmpty)
    }

    // MARK: - update

    @Test("update bumps updatedAt on success")
    func updateBumpsTimestamp() async throws {
        let project = try makeProject()
        let pane = try paneRepo.create(label: "Main", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        let originalUpdatedAt = pane.updatedAt
        try await Task.sleep(nanoseconds: 1_000_000)
        pane.label = "Main updated"
        try paneRepo.update(pane)
        #expect(pane.updatedAt > originalUpdatedAt)
    }

    @Test("update throws invalidLabel for empty label")
    func updateInvalidLabel() throws {
        let project = try makeProject()
        let pane = try paneRepo.create(label: "Main", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        pane.label = ""
        #expect(throws: WorkspacePaneError.invalidLabel) {
            try paneRepo.update(pane)
        }
    }

    @Test("update throws invalidRelativeCwd for empty cwd")
    func updateInvalidCwd() throws {
        let project = try makeProject()
        let pane = try paneRepo.create(label: "Main", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        pane.relativeCwd = "  "
        #expect(throws: WorkspacePaneError.invalidRelativeCwd) {
            try paneRepo.update(pane)
        }
    }

    @Test("update throws invalidLayoutSlot for slot below -1")
    func updateInvalidLayoutSlot() throws {
        let project = try makeProject()
        let pane = try paneRepo.create(label: "Main", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        pane.layoutSlot = -2
        #expect(throws: WorkspacePaneError.invalidLayoutSlot) {
            try paneRepo.update(pane)
        }
    }

    // MARK: - delete

    @Test("delete removes the pane from findByProject results when other panes remain")
    func deleteRemovesPane() throws {
        let project = try makeProject()
        let keepMe = try paneRepo.create(label: "Keep", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        let deleteMe = try paneRepo.create(label: "Delete", relativeCwd: "api", command: "", order: 0, layoutSlot: 1, project: project)

        try paneRepo.delete(deleteMe)

        let remaining = try paneRepo.findByProject(project)
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == keepMe.id)
    }

    @Test("delete throws cannotDeleteLastPane when removing the only pane of a project")
    func deleteRefusesLastPane() throws {
        let project = try makeProject()
        let onlyPane = try paneRepo.create(
            label: "Main",
            relativeCwd: ".",
            command: "",
            order: 0,
            layoutSlot: 0,
            project: project
        )

        #expect(throws: WorkspacePaneError.cannotDeleteLastPane) {
            try paneRepo.delete(onlyPane)
        }

        let remaining = try paneRepo.findByProject(project)
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == onlyPane.id)
    }

    @Test("delete refuses last pane even when it is unassigned (layoutSlot == -1)")
    func deleteRefusesLastPaneWhenUnassigned() throws {
        let project = try makeProject()
        let onlyPane = try paneRepo.create(
            label: "Main",
            relativeCwd: ".",
            command: "",
            order: 0,
            layoutSlot: -1,
            project: project
        )

        #expect(throws: WorkspacePaneError.cannotDeleteLastPane) {
            try paneRepo.delete(onlyPane)
        }
    }

    @Test("delete succeeds when at least two panes remain — unassigned can be deleted")
    func deleteUnassignedWithOtherPaneRemaining() throws {
        let project = try makeProject()
        let assigned = try paneRepo.create(label: "Keep", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        let unassigned = try paneRepo.create(label: "Unassigned", relativeCwd: "api", command: "", order: 0, layoutSlot: -1, project: project)

        try paneRepo.delete(unassigned)

        let remaining = try paneRepo.findByProject(project)
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == assigned.id)
    }

    @Test("cascade delete: deleting a project removes its panes")
    func cascadeDelete() throws {
        let project = try makeProject()
        _ = try paneRepo.create(label: "A", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: project)
        _ = try paneRepo.create(label: "B", relativeCwd: ".", command: "", order: 0, layoutSlot: 1, project: project)
        try projectRepo.delete(project)
        let descriptor = FetchDescriptor<WorkspacePane>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.isEmpty)
    }
}
