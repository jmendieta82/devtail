//
//  WorkspacePaneRepositoryProtocol.swift
//  Devtail
//
//  Protocol decoupling WorkspacePaneRepository from SwiftData,
//  enabling mock injection in tests.
//

import Foundation

@MainActor
protocol WorkspacePaneRepositoryProtocol {
    func create(
        label: String,
        relativeCwd: String,
        command: String,
        order: Int,
        splitDirection: String,
        stack: String?,
        project: Project
    ) throws -> WorkspacePane
    func findByProject(_ project: Project) throws -> [WorkspacePane]
    func update(_ pane: WorkspacePane) throws
    func delete(_ pane: WorkspacePane) throws
}
