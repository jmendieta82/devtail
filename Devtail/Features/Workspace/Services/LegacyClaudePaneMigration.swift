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
//  CHECKPOINT FIX (wave 2): the original v1 migration retired EVERY pane
//  with `command == "claude"`, regardless of whether it was the seed. That
//  over-reached — real user panes (e.g. label "Backend", cwd "Backend")
//  whose command happened to be exactly "claude" were blanked and then
//  vanished from the UI (ProcessSupervisor.configure skips blank commands).
//  Only the SEEDED root pane from the retired ProjectStore.createProject
//  toggle should ever be retired. Seed signature: `relativeCwd == "."` AND
//  `pane.label == pane.project?.name`.
//
//  Two idempotent passes, repair BEFORE retire:
//    1. Repair: blank-command panes that do NOT match the seed signature
//       get restored to "claude". Before the old broad migration existed,
//       the ONLY blank-command panes in existence were the seeds — so any
//       other blank pane today is collateral damage from that migration
//       having already run on this machine.
//    2. Retire: "claude" panes that DO match the seed signature get
//       blanked. Non-seed "claude" panes are left alone — they're real
//       user data and will render as stopped process cards.
//
//  Both passes are idempotent by construction: a second run finds nothing
//  left to change in either direction. Panes are never deleted — a
//  project's only pane must survive (hub Launch disables on zero panes).
//
//  `#Predicate` cannot express the relationship comparison
//  (`pane.project?.name`), so both passes fetch all panes and filter in
//  memory. Pane counts are small (one project's worth), so this is cheap.
//

import Foundation
import SwiftData

enum LegacyClaudePaneMigration {
    static func run(context: ModelContext) throws {
        let allPanes = try context.fetch(FetchDescriptor<WorkspacePane>())
        guard !allPanes.isEmpty else { return }

        var didChange = false

        // Pass 1: repair collateral damage from the old broad migration —
        // any blank-command pane that isn't a real seed gets "claude" back.
        for pane in allPanes where pane.command.isEmpty && !isSeed(pane) {
            pane.command = "claude"
            didChange = true
        }

        // Pass 2: retire only the real seeds.
        for pane in allPanes where pane.command == "claude" && isSeed(pane) {
            pane.command = ""
            didChange = true
        }

        guard didChange else { return }
        try context.save()
    }

    /// Signature of a pane seeded by the retired `ProjectStore.createProject`
    /// "Run Claude Code" toggle: the root pane of the project, labeled after
    /// the project itself.
    private static func isSeed(_ pane: WorkspacePane) -> Bool {
        pane.relativeCwd == "." && pane.label == pane.project?.name
    }
}
