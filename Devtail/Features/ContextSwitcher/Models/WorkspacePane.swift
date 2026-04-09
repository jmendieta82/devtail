//
//  WorkspacePane.swift
//  Devtail
//
//  SwiftData model for a single workspace pane in a project's terminal layout.
//  splitDirection is stored as a String sentinel: "none" | "right" | "down".
//
//  Stack note: `stack` lives here (not on Project) because a project can
//  contain multiple subfolders with different technologies (e.g. frontend
//  TypeScript + backend Django). The editor UI for this field ships in
//  Phase 2.5; auto-detection ships in Phase 2.7.
//

import Foundation
import SwiftData

@Model
final class WorkspacePane {
    @Attribute(.unique) var id: UUID
    var label: String
    var relativeCwd: String
    var command: String
    var order: Int
    var splitDirection: String
    var stack: String?
    var createdAt: Date
    var updatedAt: Date
    var project: Project?

    init(
        label: String,
        relativeCwd: String,
        command: String,
        order: Int,
        splitDirection: String,
        stack: String? = nil,
        project: Project?
    ) {
        self.id = UUID()
        self.label = label
        self.relativeCwd = relativeCwd
        self.command = command
        self.order = order
        self.splitDirection = splitDirection
        self.stack = stack
        self.project = project
        let now = Date.now
        self.createdAt = now
        self.updatedAt = now
    }
}
