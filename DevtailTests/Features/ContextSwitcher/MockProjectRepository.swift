//
//  MockProjectRepository.swift
//  DevtailTests
//
//  Test double for ProjectRepositoryProtocol. Class (not struct) so tests can
//  mutate counters by reference through the same instance held by the store.
//

import Foundation
@testable import Devtail

@MainActor
final class MockProjectRepository: ProjectRepositoryProtocol {

    // MARK: - Stub state

    var projectsToReturn: [Project] = []
    var projectToReturnOnCreate: Project?
    var errorToThrow: Error?

    // MARK: - Call counters

    var createCallCount = 0
    var deleteCallCount = 0
    var loadCallCount = 0
    var updateCallCount = 0

    // MARK: - Capture state

    var lastCreatedFields: (
        name: String,
        notes: String?,
        color: ProjectColor
    )?
    var lastUpdatedProject: Project?

    // MARK: - ProjectRepositoryProtocol

    func create(
        name: String,
        notes: String?,
        color: ProjectColor
    ) throws -> Project {
        createCallCount += 1
        lastCreatedFields = (
            name: name,
            notes: notes,
            color: color
        )
        if let errorToThrow {
            throw errorToThrow
        }
        if let projectToReturnOnCreate {
            return projectToReturnOnCreate
        }
        return Project(
            name: name,
            notes: notes,
            color: color
        )
    }

    func findAll() throws -> [Project] {
        loadCallCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
        return projectsToReturn
    }

    func findById(_ id: UUID) throws -> Project? {
        if let errorToThrow {
            throw errorToThrow
        }
        return projectsToReturn.first { $0.id == id }
    }

    func update(_ project: Project) throws {
        updateCallCount += 1
        lastUpdatedProject = project
        if let errorToThrow {
            throw errorToThrow
        }
    }

    func delete(_ project: Project) throws {
        deleteCallCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
