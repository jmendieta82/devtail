//
//  WorkspacePane.swift
//  Devtail
//
//  SwiftData model for a single workspace pane in a project's terminal layout.
//  layoutSlot tracks which slot in the project's WorkspaceLayout this pane
//  occupies. -1 is the sentinel for "unassigned".
//
//  Stack note: `stack` lives here (not on Project) because a project can
//  contain multiple subfolders with different technologies (e.g. frontend
//  TypeScript + backend Django). Same reasoning applies to `environment`:
//  a single project can have one pane that points at dev and another that
//  points at prod, so the environment is a property of the pane, not the
//  project. Both fields are optional — a pane that does not need to advertise
//  its environment simply leaves the badge empty.
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
    var layoutSlot: Int
    var stack: String?
    var isFrontend: Bool = false
    var localhostUrl: String? = nil
    /// Stored as a raw string mirror of `ProjectEnvironment` so SwiftData
    /// can persist it. Optional because not every pane corresponds to a
    /// runtime environment (a pane could be a tooling shell, a logs
    /// monitor, a notes editor, etc.). Read/write through the `environment`
    /// computed accessor — never touch `environmentRaw` directly from views.
    var environmentRaw: String?
    var createdAt: Date
    var updatedAt: Date
    var project: Project?
    /// The git branch that was active the last time the user launched this
    /// project. Compared against the current branch on Resume to detect
    /// drift and prompt a confirmation. `nil` until the first launch that
    /// succeeds branch detection for this pane.
    var lastKnownBranch: String?

    /// Strongly-typed accessor over `environmentRaw`. Returns `nil` for
    /// unset OR unrecognized raw values, so a manual edit of the SQLite
    /// store with garbage cannot crash the app — it just renders as
    /// "no environment" until the user picks a real value.
    var environment: ProjectEnvironment? {
        get {
            guard let environmentRaw else { return nil }
            return ProjectEnvironment(rawValue: environmentRaw)
        }
        set { environmentRaw = newValue?.rawValue }
    }

    init(
        label: String,
        relativeCwd: String,
        command: String,
        order: Int,
        layoutSlot: Int,
        stack: String? = nil,
        isFrontend: Bool = false,
        localhostUrl: String? = nil,
        environment: ProjectEnvironment? = nil,
        project: Project?
    ) {
        self.id = UUID()
        self.label = label
        self.relativeCwd = relativeCwd
        self.command = command
        self.order = order
        self.layoutSlot = layoutSlot
        self.stack = stack
        self.isFrontend = isFrontend
        self.localhostUrl = localhostUrl
        self.environmentRaw = environment?.rawValue
        self.project = project
        let now = Date.now
        self.createdAt = now
        self.updatedAt = now
    }
}
