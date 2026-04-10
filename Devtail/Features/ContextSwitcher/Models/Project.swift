//
//  Project.swift
//  Devtail
//
//  Core domain model: a development project the user works on.
//
//  Stack and environment note: neither field lives here. A project is a
//  root directory that can contain multiple workspace panes, each pointing
//  at a different subfolder, possibly with a different stack (frontend/TS,
//  backend/Django, …) AND a different environment (dev / staging / prod).
//  Both fields live on `WorkspacePane`.
//

import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String?
    var colorRaw: String
    var createdAt: Date
    var updatedAt: Date

    var directoryPath: String = ""
    var layoutRaw: String = WorkspaceLayout.full.rawValue

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

    /// The terminal layout for this project's workspace.
    /// Falls back to `.full` on invalid raw values so corrupted stored
    /// data cannot crash the app — it just renders a single-pane layout.
    var layout: WorkspaceLayout {
        get { WorkspaceLayout(rawValue: layoutRaw) ?? .full }
        set { layoutRaw = newValue.rawValue }
    }

    init(
        name: String,
        notes: String? = nil,
        color: ProjectColor = .gray
    ) {
        self.id = UUID()
        self.name = name
        self.notes = notes
        self.colorRaw = color.rawValue
        let now = Date.now
        self.createdAt = now
        self.updatedAt = now
    }
}
