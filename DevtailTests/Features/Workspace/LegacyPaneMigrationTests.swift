import Foundation
import Testing
import SwiftData
@testable import Devtail

/// Spec: "proyecto legacy con layout/slots abre limpio como lista de procesos".
/// The supervisor must consume panes created under the old layout model —
/// arbitrary layoutSlot values, layout-specific ordering — as a plain,
/// order-sorted process list.
@MainActor
struct LegacyPaneMigrationTests {
    @Test func legacyPanesWithLayoutSlotsBecomeAPlainProcessList() {
        let engine = MockTerminalEngine()
        let supervisor = ProcessSupervisor(engine: engine, browserLauncher: MockBrowserLauncher())
        // Quarters-layout project from the old world: slots 0-3, shuffled order.
        let legacy = [
            WorkspacePane(label: "docker", relativeCwd: ".", command: "docker compose up",
                          order: 3, layoutSlot: 2, project: nil),
            WorkspacePane(label: "back", relativeCwd: "api", command: "npm run start:dev",
                          order: 0, layoutSlot: 0, project: nil),
            WorkspacePane(label: "front", relativeCwd: "web", command: "ng serve",
                          order: 1, layoutSlot: 1, project: nil),
        ]
        supervisor.configure(panes: legacy, root: URL(fileURLWithPath: "/tmp/legacy"))
        #expect(supervisor.processes.map(\.name) == ["back", "front", "docker"])
        #expect(supervisor.processes.map(\.state) == [.stopped, .stopped, .stopped])
    }
}

/// Spec: legacy projects created with the retired "Run Claude Code" toggle
/// seeded a root pane with `command: "claude"`. That pane is now redundant
/// with the first-class agent tab and must retire to a blank command (a
/// placeholder, per ProcessSupervisorTests.configureSkipsBlankCommandPanes)
/// rather than being deleted — a project's only pane must survive.
///
/// CHECKPOINT FIX (wave 2): the original broad migration ("claude" -> "" for
/// ANY pane) over-reached — real user panes whose command happened to be
/// exactly "claude" (e.g. a pane labeled "Backend" with cwd "Backend") were
/// blanked and then vanished from the UI (the supervisor skips blank
/// commands). Only the SEEDED root pane must retire. Seed signature (from
/// ProjectStore.createProject's now-retired seeding call): `relativeCwd == "."`
/// AND `pane.label == pane.project?.name`.
///
/// `run(context:)` is now two idempotent passes:
///   1. Repair pass (runs first): blank-command panes that do NOT match the
///      seed signature get restored to "claude" — heals machines where the
///      old broad migration already blanked real user panes. Before the
///      broad migration existed, the ONLY blank-command panes in existence
///      were the seeds, so any other blank pane today was collateral damage.
///   2. Retire pass: "claude" panes that DO match the seed signature get
///      blanked. Non-seed "claude" panes are left alone — they're real user
///      data and will render as stopped process cards.
@MainActor
struct LegacyClaudePaneMigrationTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Project.self, QuickLink.self, WorkspacePane.self,
            configurations: config
        )
        return ModelContext(container)
    }

    /// Inserts a project (so `pane.project?.name` is a real relationship,
    /// not nil) and a pane attached to it, wiring both sides of the
    /// SwiftData relationship like the app does.
    @discardableResult
    private func makePane(
        context: ModelContext,
        projectName: String,
        label: String,
        relativeCwd: String,
        command: String
    ) -> (project: Project, pane: WorkspacePane) {
        let project = Project(name: projectName)
        context.insert(project)
        let pane = WorkspacePane(label: label, relativeCwd: relativeCwd, command: command,
                                  order: 0, layoutSlot: 0, project: project)
        context.insert(pane)
        project.workspacePanes.append(pane)
        return (project, pane)
    }

    // MARK: - Retire pass: seed panes only

    @Test func seedPaneClaudeCommandBecomesBlank() throws {
        let context = try makeContext()
        let (_, pane) = makePane(
            context: context, projectName: "alpha",
            label: "alpha", relativeCwd: ".", command: "claude"
        )
        try context.save()

        try LegacyClaudePaneMigration.run(context: context)

        #expect(pane.command == "")
    }

    @Test func nonSeedPaneWithClaudeCommandIsUntouchedByRetirePass() throws {
        let context = try makeContext()
        // Real user pane: label/cwd "Backend", unrelated to the project name,
        // whose command just happens to be exactly "claude".
        let (_, pane) = makePane(
            context: context, projectName: "alpha",
            label: "Backend", relativeCwd: "Backend", command: "claude"
        )
        try context.save()

        try LegacyClaudePaneMigration.run(context: context)

        #expect(pane.command == "claude")
    }

    @Test func userConfiguredClaudeContinueCommandIsUntouched() throws {
        let context = try makeContext()
        let (_, pane) = makePane(
            context: context, projectName: "alpha",
            label: "alpha", relativeCwd: ".", command: "claude --continue"
        )
        try context.save()

        try LegacyClaudePaneMigration.run(context: context)

        #expect(pane.command == "claude --continue")
    }

    @Test func unrelatedCommandIsUntouched() throws {
        let context = try makeContext()
        let (_, pane) = makePane(
            context: context, projectName: "alpha",
            label: "alpha", relativeCwd: ".", command: "npm run dev"
        )
        try context.save()

        try LegacyClaudePaneMigration.run(context: context)

        #expect(pane.command == "npm run dev")
    }

    @Test func runningTwiceIsStableForSeedPane() throws {
        let context = try makeContext()
        let (_, pane) = makePane(
            context: context, projectName: "alpha",
            label: "alpha", relativeCwd: ".", command: "claude"
        )
        try context.save()

        try LegacyClaudePaneMigration.run(context: context)
        try LegacyClaudePaneMigration.run(context: context)

        #expect(pane.command == "")
    }

    // MARK: - Repair pass: collateral damage from the old broad migration

    @Test func blankNonSeedPaneIsRepairedToClaude() throws {
        let context = try makeContext()
        // This models a machine where the old (wave 1) broad migration
        // already ran and blanked a real user pane labeled "Backend".
        let (_, pane) = makePane(
            context: context, projectName: "alpha",
            label: "Backend", relativeCwd: "Backend", command: ""
        )
        try context.save()

        try LegacyClaudePaneMigration.run(context: context)

        #expect(pane.command == "claude")
    }

    @Test func blankSeedPaneStaysBlank() throws {
        let context = try makeContext()
        let (_, pane) = makePane(
            context: context, projectName: "alpha",
            label: "alpha", relativeCwd: ".", command: ""
        )
        try context.save()

        try LegacyClaudePaneMigration.run(context: context)

        #expect(pane.command == "")
    }

    @Test func runningTwiceIsStableForRepairedPane() throws {
        let context = try makeContext()
        let (_, pane) = makePane(
            context: context, projectName: "alpha",
            label: "Backend", relativeCwd: "Backend", command: ""
        )
        try context.save()

        try LegacyClaudePaneMigration.run(context: context)
        try LegacyClaudePaneMigration.run(context: context)

        #expect(pane.command == "claude")
    }

    /// End-to-end scenario matching the checkpoint finding: a machine with
    /// one real seed pane already retired to "" AND one real user pane
    /// ("Backend") collaterally blanked by the old broad migration. After
    /// running the new two-pass migration, the seed stays blank and the
    /// user's Backend pane is restored to "claude" so it shows up again.
    @Test func mixedMachineRepairsCollateralAndKeepsSeedRetired() throws {
        let context = try makeContext()
        let project = Project(name: "alpha")
        context.insert(project)
        let seed = WorkspacePane(label: "alpha", relativeCwd: ".", command: "",
                                  order: 0, layoutSlot: 0, project: project)
        let backend = WorkspacePane(label: "Backend", relativeCwd: "Backend", command: "",
                                     order: 1, layoutSlot: 1, project: project)
        context.insert(seed)
        context.insert(backend)
        project.workspacePanes.append(seed)
        project.workspacePanes.append(backend)
        try context.save()

        try LegacyClaudePaneMigration.run(context: context)

        #expect(seed.command == "")
        #expect(backend.command == "claude")
    }
}
