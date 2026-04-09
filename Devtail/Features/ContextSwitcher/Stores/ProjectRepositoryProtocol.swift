//
//  ProjectRepositoryProtocol.swift
//  Devtail
//
//  Contract the ProjectStore depends on, decoupling it from SwiftData.
//

import Foundation

@MainActor
protocol ProjectRepositoryProtocol {
    func create(
        name: String,
        notes: String?,
        color: ProjectColor
    ) throws -> Project
    func findAll() throws -> [Project]
    func findById(_ id: UUID) throws -> Project?
    func update(_ project: Project) throws
    func delete(_ project: Project) throws
}
