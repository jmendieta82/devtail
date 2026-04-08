//
//  Project.swift
//  Devtail
//
//  Core domain model: a development project the user works on.
//

import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String?
    var colorRaw: String
    var environmentRaw: String
    var stack: String?
    var createdAt: Date
    var updatedAt: Date

    var directoryPath: String = ""

    @Relationship(deleteRule: .cascade, inverse: \QuickLink.project)
    var quickLinks: [QuickLink] = []

    @Relationship(deleteRule: .cascade, inverse: \WorkspacePane.project)
    var workspacePanes: [WorkspacePane] = []

    /// User-assigned color from the closed `ProjectColor` palette.
    /// Stored as raw string for SwiftData and surfaced as the enum.
    var color: ProjectColor {
        get { ProjectColor(rawValue: colorRaw) ?? .gray }
        set { colorRaw = newValue.rawValue }
    }

    /// Environment this project points at (dev / staging / prod).
    var environment: ProjectEnvironment {
        get { ProjectEnvironment(rawValue: environmentRaw) ?? .dev }
        set { environmentRaw = newValue.rawValue }
    }

    init(
        name: String,
        notes: String? = nil,
        color: ProjectColor = .gray,
        environment: ProjectEnvironment = .dev,
        stack: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.notes = notes
        self.colorRaw = color.rawValue
        self.environmentRaw = environment.rawValue
        self.stack = stack
        let now = Date.now
        self.createdAt = now
        self.updatedAt = now
    }
}
