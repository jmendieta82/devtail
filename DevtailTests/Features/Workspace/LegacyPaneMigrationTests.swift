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

    @Test func exactClaudeCommandBecomesBlank() throws {
        let context = try makeContext()
        let pane = WorkspacePane(label: "root", relativeCwd: ".", command: "claude",
                                  order: 0, layoutSlot: 0, project: nil)
        context.insert(pane)
        try context.save()

        try LegacyClaudePaneMigration.run(context: context)

        #expect(pane.command == "")
    }

    @Test func userConfiguredClaudeContinueCommandIsUntouched() throws {
        let context = try makeContext()
        let pane = WorkspacePane(label: "root", relativeCwd: ".", command: "claude --continue",
                                  order: 0, layoutSlot: 0, project: nil)
        context.insert(pane)
        try context.save()

        try LegacyClaudePaneMigration.run(context: context)

        #expect(pane.command == "claude --continue")
    }

    @Test func unrelatedCommandIsUntouched() throws {
        let context = try makeContext()
        let pane = WorkspacePane(label: "root", relativeCwd: ".", command: "npm run dev",
                                  order: 0, layoutSlot: 0, project: nil)
        context.insert(pane)
        try context.save()

        try LegacyClaudePaneMigration.run(context: context)

        #expect(pane.command == "npm run dev")
    }

    @Test func runningTwiceIsStable() throws {
        let context = try makeContext()
        let pane = WorkspacePane(label: "root", relativeCwd: ".", command: "claude",
                                  order: 0, layoutSlot: 0, project: nil)
        context.insert(pane)
        try context.save()

        try LegacyClaudePaneMigration.run(context: context)
        try LegacyClaudePaneMigration.run(context: context)

        #expect(pane.command == "")
    }
}
