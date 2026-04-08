//
//  WorkspacePane.swift
//  Devtail
//
//  SwiftData model for a single workspace pane in a project's terminal layout.
//  splitDirection is stored as a String sentinel: "none" | "right" | "down".
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
    var createdAt: Date
    var updatedAt: Date
    var project: Project?

    init(
        label: String,
        relativeCwd: String,
        command: String,
        order: Int,
        splitDirection: String,
        project: Project?
    ) {
        self.id = UUID()
        self.label = label
        self.relativeCwd = relativeCwd
        self.command = command
        self.order = order
        self.splitDirection = splitDirection
        self.project = project
        let now = Date.now
        self.createdAt = now
        self.updatedAt = now
    }
}
