//
//  ProjectRepository.swift
//  Devtail
//
//  CRUD operations for the Project entity, backed by SwiftData.
//

import Foundation
import SwiftData

@MainActor
struct ProjectRepository: ProjectRepositoryProtocol {
    let context: ModelContext

    func create(
        name: String,
        notes: String? = nil,
        color: ProjectColor = .gray,
        environment: ProjectEnvironment = .dev,
        stack: String? = nil
    ) throws -> Project {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProjectError.invalidName
        }

        let project = Project(
            name: trimmed,
            notes: notes,
            color: color,
            environment: environment,
            stack: stack
        )
        context.insert(project)
        try context.save()
        return project
    }

    func findAll() throws -> [Project] {
        let descriptor = FetchDescriptor<Project>()
        return try context.fetch(descriptor)
    }

    func findById(_ id: UUID) throws -> Project? {
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    func update(_ project: Project) throws {
        let trimmed = project.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProjectError.invalidName
        }

        project.name = trimmed
        project.updatedAt = .now
        try context.save()
    }

    func delete(_ project: Project) throws {
        context.delete(project)
        try context.save()
    }
}
