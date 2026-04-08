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
            splitDirection: "none",
            project: project
        )
        #expect(pane.label == "Main")
        #expect(pane.relativeCwd == ".")
        #expect(pane.order == 0)
        #expect(pane.project?.id == project.id)
    }

    @Test("create assigns incremental order regardless of passed order param")
    func createAssignsIncrementalOrder() throws {
        let project = try makeProject()
        let a = try paneRepo.create(label: "A", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)
        let b = try paneRepo.create(label: "B", relativeCwd: "api", command: "", order: 0, splitDirection: "right", project: project)
        let c = try paneRepo.create(label: "C", relativeCwd: "web", command: "", order: 0, splitDirection: "down", project: project)
        #expect(a.order == 0)
        #expect(b.order == 1)
        #expect(c.order == 2)
    }

    @Test("create throws invalidLabel for empty label")
    func createInvalidLabel() throws {
        let project = try makeProject()
        #expect(throws: WorkspacePaneError.invalidLabel) {
            try paneRepo.create(label: "   ", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)
        }
    }

    @Test("create throws invalidRelativeCwd for empty cwd")
    func createInvalidRelativeCwd() throws {
        let project = try makeProject()
        #expect(throws: WorkspacePaneError.invalidRelativeCwd) {
            try paneRepo.create(label: "Main", relativeCwd: "  ", command: "", order: 0, splitDirection: "none", project: project)
        }
    }

    @Test("create throws invalidSplitDirection for unknown direction")
    func createInvalidSplitDirection() throws {
        let project = try makeProject()
        #expect(throws: WorkspacePaneError.invalidSplitDirection) {
            try paneRepo.create(label: "Main", relativeCwd: ".", command: "", order: 0, splitDirection: "diagonal", project: project)
        }
    }

    @Test("create accepts none, right, down as valid split directions")
    func createAcceptsValidSplitDirections() throws {
        let project = try makeProject()
        #expect(throws: Never.self) {
            try paneRepo.create(label: "A", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)
        }
        #expect(throws: Never.self) {
            try paneRepo.create(label: "B", relativeCwd: ".", command: "", order: 0, splitDirection: "right", project: project)
        }
        #expect(throws: Never.self) {
            try paneRepo.create(label: "C", relativeCwd: ".", command: "", order: 0, splitDirection: "down", project: project)
        }
    }

    @Test("create allows empty command without throwing")
    func createAllowsEmptyCommand() throws {
        let project = try makeProject()
        #expect(throws: Never.self) {
            try paneRepo.create(label: "Main", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)
        }
    }

    // MARK: - findByProject

    @Test("findByProject returns panes sorted by order ascending")
    func findByProjectSorted() throws {
        let project = try makeProject()
        _ = try paneRepo.create(label: "A", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)
        _ = try paneRepo.create(label: "B", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)
        _ = try paneRepo.create(label: "C", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)
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
        let pane = try paneRepo.create(label: "Main", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)
        let originalUpdatedAt = pane.updatedAt
        try await Task.sleep(nanoseconds: 1_000_000)
        pane.label = "Main updated"
        try paneRepo.update(pane)
        #expect(pane.updatedAt > originalUpdatedAt)
    }

    @Test("update throws invalidLabel for empty label")
    func updateInvalidLabel() throws {
        let project = try makeProject()
        let pane = try paneRepo.create(label: "Main", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)
        pane.label = ""
        #expect(throws: WorkspacePaneError.invalidLabel) {
            try paneRepo.update(pane)
        }
    }

    @Test("update throws invalidRelativeCwd for empty cwd")
    func updateInvalidCwd() throws {
        let project = try makeProject()
        let pane = try paneRepo.create(label: "Main", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)
        pane.relativeCwd = "  "
        #expect(throws: WorkspacePaneError.invalidRelativeCwd) {
            try paneRepo.update(pane)
        }
    }

    // MARK: - delete

    @Test("delete removes the pane from findByProject results")
    func deleteRemovesPane() throws {
        let project = try makeProject()
        let pane = try paneRepo.create(label: "Main", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)
        try paneRepo.delete(pane)
        let remaining = try paneRepo.findByProject(project)
        #expect(remaining.isEmpty)
    }

    @Test("cascade delete: deleting a project removes its panes")
    func cascadeDelete() throws {
        let project = try makeProject()
        _ = try paneRepo.create(label: "A", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)
        _ = try paneRepo.create(label: "B", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: project)
        try projectRepo.delete(project)
        let descriptor = FetchDescriptor<WorkspacePane>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.isEmpty)
    }

    // MARK: - isValidSplitDirection helper

    @Test("isValidSplitDirection helper edge cases")
    func isValidSplitDirectionHelper() {
        #expect(isValidSplitDirection("none") == true)
        #expect(isValidSplitDirection("right") == true)
        #expect(isValidSplitDirection("down") == true)
        #expect(isValidSplitDirection("diagonal") == false)
        #expect(isValidSplitDirection("") == false)
        #expect(isValidSplitDirection("NONE") == false)
        #expect(isValidSplitDirection("left") == false)
    }
}
