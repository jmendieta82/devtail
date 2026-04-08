//
//  ProjectRepositoryTests.swift
//  DevtailTests
//
//  Tests for the ProjectRepository CRUD operations.
//

import Testing
import Foundation
import SwiftData
@testable import Devtail

@MainActor
@Suite("ProjectRepository")
struct ProjectRepositoryTests {

    let container: ModelContainer
    let context: ModelContext
    let repository: ProjectRepository

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Project.self, configurations: config)
        context = ModelContext(container)
        repository = ProjectRepository(context: context)
    }

    // MARK: - Group A: create

    @Test("create persists project with trimmed name")
    func createPersistsProjectWithTrimmedName() throws {
        let project = try repository.create(name: "  My Project  ")

        #expect(project.name == "My Project")
        #expect(project.notes == nil)
    }

    @Test("create throws invalidName for empty string")
    func createThrowsInvalidNameForEmptyString() throws {
        #expect(throws: ProjectError.invalidName) {
            _ = try repository.create(name: "")
        }
    }

    @Test("create throws invalidName for whitespace-only string")
    func createThrowsInvalidNameForWhitespaceOnly() throws {
        #expect(throws: ProjectError.invalidName) {
            _ = try repository.create(name: "   \n\t  ")
        }
    }

    @Test("create persists color, environment, and stack when provided")
    func createPersistsAllOptionalFields() throws {
        let project = try repository.create(
            name: "Full Project",
            notes: "with notes",
            color: .blue,
            environment: .staging,
            stack: "Swift"
        )

        #expect(project.color == .blue)
        #expect(project.environment == .staging)
        #expect(project.stack == "Swift")
        #expect(project.notes == "with notes")
    }

    // MARK: - Group B: findAll

    @Test("findAll returns all inserted projects")
    func findAllReturnsAllInsertedProjects() throws {
        _ = try repository.create(name: "Project A")
        _ = try repository.create(name: "Project B")

        let projects = try repository.findAll()

        #expect(projects.count == 2)
    }

    @Test("findAll returns empty when no projects exist")
    func findAllReturnsEmptyWhenNoProjects() throws {
        let projects = try repository.findAll()

        #expect(projects.isEmpty)
    }

    // MARK: - Group C: findById

    @Test("findById returns the matching project")
    func findByIdReturnsMatchingProject() throws {
        let created = try repository.create(name: "Project A")

        let found = try repository.findById(created.id)

        #expect(found?.id == created.id)
        #expect(found?.name == "Project A")
    }

    @Test("findById returns nil when the id is not found")
    func findByIdReturnsNilWhenMissing() throws {
        let randomId = UUID()

        let found = try repository.findById(randomId)

        #expect(found == nil)
    }

    // MARK: - Group D: update

    @Test("update bumps updatedAt and persists changes")
    func updateBumpsUpdatedAtAndPersistsChanges() async throws {
        let project = try repository.create(name: "Original Name")
        let originalUpdatedAt = project.updatedAt

        try await Task.sleep(for: .milliseconds(10))

        project.name = "Updated Name"
        try repository.update(project)

        #expect(project.updatedAt > originalUpdatedAt)

        let refetched = try repository.findById(project.id)
        #expect(refetched?.name == "Updated Name")
    }

    @Test("update persists changes to color, environment, and stack")
    func updatePersistsFieldChangesIncludingColorEnvironmentStack() throws {
        let project = try repository.create(
            name: "Original",
            color: .gray,
            environment: .dev,
            stack: nil
        )

        project.color = .purple
        project.environment = .prod
        project.stack = "Rust"
        try repository.update(project)

        let refetched = try repository.findById(project.id)
        #expect(refetched?.color == .purple)
        #expect(refetched?.environment == .prod)
        #expect(refetched?.stack == "Rust")
    }

    // MARK: - Group E: delete

    @Test("delete removes the project from the context")
    func deleteRemovesProjectFromContext() throws {
        let project = try repository.create(name: "To Be Deleted")

        try repository.delete(project)

        let all = try repository.findAll()
        #expect(all.isEmpty)
    }
}
