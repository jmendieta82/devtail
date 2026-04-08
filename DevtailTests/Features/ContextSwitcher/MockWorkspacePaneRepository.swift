//
//  MockWorkspacePaneRepository.swift
//  DevtailTests
//
//  Test double for WorkspacePaneRepositoryProtocol. Class (not struct) so
//  tests can mutate counters by reference through the same instance in store.
//

import Foundation
@testable import Devtail

@MainActor
final class MockWorkspacePaneRepository: WorkspacePaneRepositoryProtocol {

    // MARK: - Stub state

    var paneToReturn: WorkspacePane?
    var panesToReturn: [WorkspacePane] = []
    var errorToThrow: Error?

    // MARK: - Call counters

    var createCallCount = 0
    var findByProjectCallCount = 0
    var updateCallCount = 0
    var deleteCallCount = 0

    // MARK: - Capture state

    var lastCreateLabel: String?
    var lastCreateRelativeCwd: String?
    var lastCreateCommand: String?
    var lastCreateSplitDirection: String?
    var lastCreateProject: Project?
    var lastUpdatedPane: WorkspacePane?
    var lastDeletedPane: WorkspacePane?

    // MARK: - WorkspacePaneRepositoryProtocol

    func create(
        label: String,
        relativeCwd: String,
        command: String,
        order: Int,
        splitDirection: String,
        project: Project
    ) throws -> WorkspacePane {
        createCallCount += 1
        lastCreateLabel = label
        lastCreateRelativeCwd = relativeCwd
        lastCreateCommand = command
        lastCreateSplitDirection = splitDirection
        lastCreateProject = project
        if let errorToThrow {
            throw errorToThrow
        }
        if let paneToReturn {
            return paneToReturn
        }
        return WorkspacePane(
            label: label,
            relativeCwd: relativeCwd,
            command: command,
            order: order,
            splitDirection: splitDirection,
            project: project
        )
    }

    func findByProject(_ project: Project) throws -> [WorkspacePane] {
        findByProjectCallCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
        return panesToReturn
    }

    func update(_ pane: WorkspacePane) throws {
        updateCallCount += 1
        lastUpdatedPane = pane
        if let errorToThrow {
            throw errorToThrow
        }
    }

    func delete(_ pane: WorkspacePane) throws {
        deleteCallCount += 1
        lastDeletedPane = pane
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
