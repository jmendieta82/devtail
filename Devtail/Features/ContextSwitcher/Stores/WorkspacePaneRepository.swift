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
        stack: String? = nil,
        environment: ProjectEnvironment? = nil,
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
            stack: normalizedStack(stack),
            environment: environment,
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
        pane.stack = normalizedStack(pane.stack)
        pane.updatedAt = .now
        try context.save()
    }

    func delete(_ pane: WorkspacePane) throws {
        // Product invariant: a workspace must always have at least
        // one pane. If this delete would leave the project with zero
        // panes, refuse — the UI surfaces this as a disabled button
        // with an explanatory tooltip, so the user understands why
        // the action is not available rather than seeing it silently
        // succeed and ending up with a launcher that can't anchor.
        if let project = pane.project, project.workspacePanes.count <= 1 {
            throw WorkspacePaneError.cannotDeleteLastPane
        }
        context.delete(pane)
        try context.save()
    }

    /// Trims whitespace and collapses empty strings to nil so the model
    /// stays consistent (`nil` vs `""` are the same concept for the UI but
    /// different for storage queries).
    private func normalizedStack(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Returns true for the three valid split direction sentinels.
/// File-scope so it is accessible in tests via @testable import Devtail.
func isValidSplitDirection(_ value: String) -> Bool {
    value == "none" || value == "right" || value == "down"
}
