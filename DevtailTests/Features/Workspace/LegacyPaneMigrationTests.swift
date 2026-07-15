import Foundation
import Testing
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
