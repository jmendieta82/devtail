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
/// CHECKPOINT FIX (wave 3): the wave-2 repair pass (blank non-seed panes
/// restored to "claude") turned into an injection vector: blank commands are
/// a legitimate state today (ProjectStore seeds root panes blank, the
/// repository accepts blank on create/edit), and the migration runs on every
/// launch — so any pane the user left blank got "claude" written into it on
/// the next start (field finding: a "Backend" pane spawning Claude Code).
/// The repair window closed the day wave 1 ran; the pass is REMOVED.
///
/// Wave 3 also drops `label == project.name` from the seed signature:
/// renaming a project orphaned its real seed pane (field finding: two
/// renamed projects whose root panes escaped retirement and were re-claude'd
/// by the repair pass). A ROOT pane (`relativeCwd == "."`) running exactly
/// "claude" is redundant with the agent tab by definition — retire it
/// regardless of label. Non-root "claude" panes remain untouched user data.
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

    @Test func nonRootPaneWithClaudeCommandIsUntouchedByRetirePass() throws {
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

    /// Wave-3 field finding: renaming a project breaks `label == project.name`,
    /// so its seed pane escaped retirement under the wave-2 signature. A root
    /// pane running exactly "claude" retires regardless of label.
    @Test func renamedProjectRootClaudePaneIsRetired() throws {
        let context = try makeContext()
        let (_, pane) = makePane(
            context: context, projectName: "INCLUSIVA PROYECTO",
            label: "PROYECTO", relativeCwd: ".", command: "claude"
        )
        try context.save()

        try LegacyClaudePaneMigration.run(context: context)

        #expect(pane.command == "")
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

    // MARK: - Blank panes are a legitimate state (wave 3: repair pass removed)

    /// Regression for the wave-2 injection bug: a user pane left with a blank
    /// command must NEVER have "claude" written into it by the migration.
    @Test func blankNonSeedPaneStaysBlank() throws {
        let context = try makeContext()
        let (_, pane) = makePane(
            context: context, projectName: "alpha",
            label: "Backend", relativeCwd: "Backend", command: ""
        )
        try context.save()

        try LegacyClaudePaneMigration.run(context: context)

        #expect(pane.command == "")
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

    @Test func runningTwiceIsStableForBlankPane() throws {
        let context = try makeContext()
        let (_, pane) = makePane(
            context: context, projectName: "alpha",
            label: "Backend", relativeCwd: "Backend", command: ""
        )
        try context.save()

        try LegacyClaudePaneMigration.run(context: context)
        try LegacyClaudePaneMigration.run(context: context)

        #expect(pane.command == "")
    }

    /// End-to-end scenario matching the wave-3 field finding: a retired seed,
    /// a user pane left blank on purpose, and a renamed project's root claude
    /// pane. Blanks stay blank; the renamed root retires.
    @Test func mixedMachineLeavesBlanksAloneAndRetiresRenamedRoot() throws {
        let context = try makeContext()
        let project = Project(name: "INCLUSIVA PROYECTO")
        context.insert(project)
        let renamedRoot = WorkspacePane(label: "PROYECTO", relativeCwd: ".", command: "claude",
                                        order: 0, layoutSlot: 0, project: project)
        let backend = WorkspacePane(label: "Backend", relativeCwd: "Backend", command: "",
                                     order: 1, layoutSlot: 1, project: project)
        context.insert(renamedRoot)
        context.insert(backend)
        project.workspacePanes.append(renamedRoot)
        project.workspacePanes.append(backend)
        try context.save()

        try LegacyClaudePaneMigration.run(context: context)

        #expect(renamedRoot.command == "")
        #expect(backend.command == "")
    }
}
