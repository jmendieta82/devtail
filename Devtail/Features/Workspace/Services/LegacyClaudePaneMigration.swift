//
//  LegacyClaudePaneMigration.swift
//  Devtail
//
//  One-shot data migration: projects created with the retired "Run Claude
//  Code" toggle seeded a root pane with `command: "claude"`. That pane is
//  now redundant with the first-class agent tab — it showed up as a
//  managed process card + center tab running a read-only Claude. Rewrite
//  its command to blank so ProcessSupervisor.configure treats it as a
//  placeholder (see ProcessSupervisorTests.configureSkipsBlankCommandPanes)
//  instead of a spurious process.
//
//  Idempotent by construction: the fetch predicate matches only the exact
//  legacy string, so a second run finds nothing to change. Panes are never
//  deleted — a project's only pane must survive (hub Launch disables on
//  zero panes).
//

import Foundation
import SwiftData

enum LegacyClaudePaneMigration {
    static func run(context: ModelContext) throws {
        let descriptor = FetchDescriptor<WorkspacePane>(
            predicate: #Predicate { $0.command == "claude" }
        )
        let legacyPanes = try context.fetch(descriptor)
        guard !legacyPanes.isEmpty else { return }

        for pane in legacyPanes {
            pane.command = ""
        }
        try context.save()
    }
}
