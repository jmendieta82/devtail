//
//  WorkspacePaneRepository.swift
//  Devtail
//
//  SwiftData-backed CRUD for WorkspacePane. Validates label, relativeCwd,
//  and splitDirection. Computes monotonically increasing order on create.
//

import Foundation
import SwiftData

@MainActor
struct WorkspacePaneRepository: WorkspacePaneRepositoryProtocol {
    let context: ModelContext

    func create(
        label: String,
        relativeCwd: String,
        command: String,
        order: Int,
        splitDirection: String,
        project: Project
    ) throws -> WorkspacePane {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else {
            throw WorkspacePaneError.invalidLabel
        }
        let trimmedCwd = relativeCwd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCwd.isEmpty else {
            throw WorkspacePaneError.invalidRelativeCwd
        }
        guard isValidSplitDirection(splitDirection) else {
            throw WorkspacePaneError.invalidSplitDirection
        }
        let nextOrder = (project.workspacePanes.map { $0.order }.max() ?? -1) + 1
        let pane = WorkspacePane(
            label: trimmedLabel,
            relativeCwd: trimmedCwd,
            command: command,
            order: nextOrder,
            splitDirection: splitDirection,
            project: project
        )
        context.insert(pane)
        try context.save()
        return pane
    }

    func findByProject(_ project: Project) throws -> [WorkspacePane] {
        project.workspacePanes.sorted { $0.order < $1.order }
    }

    func update(_ pane: WorkspacePane) throws {
        let trimmedLabel = pane.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else {
            throw WorkspacePaneError.invalidLabel
        }
        let trimmedCwd = pane.relativeCwd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCwd.isEmpty else {
            throw WorkspacePaneError.invalidRelativeCwd
        }
        guard isValidSplitDirection(pane.splitDirection) else {
            throw WorkspacePaneError.invalidSplitDirection
        }
        pane.label = trimmedLabel
        pane.relativeCwd = trimmedCwd
        pane.updatedAt = .now
        try context.save()
    }

    func delete(_ pane: WorkspacePane) throws {
        context.delete(pane)
        try context.save()
    }
}

/// Returns true for the three valid split direction sentinels.
/// File-scope so it is accessible in tests via @testable import Devtail.
func isValidSplitDirection(_ value: String) -> Bool {
    value == "none" || value == "right" || value == "down"
}
