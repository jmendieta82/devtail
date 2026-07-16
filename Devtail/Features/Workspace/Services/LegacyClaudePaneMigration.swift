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
//  CHECKPOINT FIX (wave 3): the wave-2 "repair" pass (blank non-seed panes
//  restored to "claude") is REMOVED. It assumed the only blank-command panes
//  in existence were old seeds, but blank is a legitimate state today:
//  ProjectStore.createProject seeds root panes with `command: ""` and the
//  repository accepts blank on create/edit. Since this migration runs on
//  every launch, the repair pass injected "claude" into any pane the user
//  left blank (field finding: a "Backend" pane spawning Claude Code on
//  play). The collateral damage it existed to heal was healed the one day
//  wave 1 ran; blank panes must never be rewritten again.
//
//  Wave 3 also drops `label == pane.project?.name` from the seed signature:
//  renaming a project orphans its seed pane (field finding: two renamed
//  projects whose root claude panes escaped retirement). A ROOT pane
//  (`relativeCwd == "."`) running exactly "claude" is redundant with the
//  agent tab by definition — retire it regardless of label. Non-root
//  "claude" panes are real user data and stay untouched.
//
//  The retire pass is idempotent by construction: a second run finds
//  nothing left to change. Panes are never deleted — a project's only pane
//  must survive (hub Launch disables on zero panes).
//

import Foundation
import SwiftData

enum LegacyClaudePaneMigration {
    static func run(context: ModelContext) throws {
        let allPanes = try context.fetch(FetchDescriptor<WorkspacePane>())
        guard !allPanes.isEmpty else { return }

        var didChange = false

        for pane in allPanes where pane.command == "claude" && pane.relativeCwd == "." {
            pane.command = ""
            didChange = true
        }

        guard didChange else { return }
        try context.save()
    }
}
