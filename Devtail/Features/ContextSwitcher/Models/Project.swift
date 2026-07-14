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
    /// Security-scoped bookmark for `directoryPath`. Required under App
    /// Sandbox so the app can re-access the folder across launches and
    /// pass it to external apps (VSCode, Ghostty) without triggering
    /// "no tiene permiso para abrir X" errors. `nil` for projects created
    /// before this field existed — those get a bookmark the next time the
    /// user opens the directory picker.
    var directoryBookmark: Data?
    var layoutRaw: String = WorkspaceLayout.full.rawValue
    /// Stored raw value for `launchTarget`. SwiftData lightweight migration:
    /// existing rows receive the Swift default `"auto"` automatically.
    var launchTargetRaw: String = LaunchTarget.auto.rawValue
    /// Timestamp of the last time the user pressed Launch for this project.
    /// Updated BEFORE the workspace opens (intent, not success). `nil` when
    /// the project has never been launched. Drives the "Last seen" chip in
    /// the sidebar and the Resume button visibility in the detail header.
    var lastLaunchedAt: Date?

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

    /// Where to open the Ghostty workspace: auto (window-count check at runtime),
    /// new tab in the front window, or always a new OS window.
    /// Falls back to `.auto` on invalid raw values.
    var launchTarget: LaunchTarget {
        get { LaunchTarget(rawValue: launchTargetRaw) ?? .auto }
        set { launchTargetRaw = newValue.rawValue }
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
