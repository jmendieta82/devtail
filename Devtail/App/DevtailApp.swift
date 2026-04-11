//
//  DevtailApp.swift
//  Devtail
//
//  Created by Javier Mendieta Ortega on 6/04/26.
//

import SwiftUI
import SwiftData

@main
struct DevtailApp: App {
    @State private var modelContainer: ModelContainer
    @State private var projectStore: ProjectStore
    @State private var activityMonitor = WorkspaceActivityMonitor()
    @Environment(\.openWindow) private var openWindow

    init() {
        let container = PersistenceController.makeContainer()
        let repository = ProjectRepository(context: container.mainContext)
        let quickLinkRepository = QuickLinkRepository(context: container.mainContext)
        let workspacePaneRepository = WorkspacePaneRepository(context: container.mainContext)
        let launcher = WorkspaceLauncher()
        let store = ProjectStore(
            repository: repository,
            quickLinkRepository: quickLinkRepository,
            workspacePaneRepository: workspacePaneRepository,
            launcher: launcher
        )
        _modelContainer = State(initialValue: container)
        _projectStore = State(initialValue: store)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView()
        } label: {
            Image(systemName: "terminal.fill")
        }
        .menuBarExtraStyle(.window)
        .modelContainer(modelContainer)
        .environment(projectStore)
        .environment(activityMonitor)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: WindowID.dashboard, value: DashboardIntent.createProject)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        WindowGroup("Devtail", id: WindowID.dashboard, for: DashboardIntent.self) { $intent in
            DashboardRootView(initialIntent: intent ?? .none)
        } defaultValue: {
            .none
        }
        .modelContainer(modelContainer)
        .environment(projectStore)
        .environment(activityMonitor)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

        Window("Settings", id: WindowID.settings) {
            ComingSoonView(title: "Settings")
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 300)
    }
}

enum WindowID {
    static let dashboard = "devtail.dashboard"
    static let settings  = "devtail.settings"
}

/// Why this exists: the dashboard window can be opened from multiple places
/// (popup "Manage…" button, ⌘N keyboard shortcut, future deep links). Each
/// caller may want the dashboard to land in a specific state — idle, with the
/// create-project sheet already visible, or with the edit sheet for a given
/// project. Using a Codable enum as the WindowGroup value lets SwiftUI
/// natively carry that intent through `openWindow(id:value:)`.
enum DashboardIntent: Codable, Hashable {
    case none
    case createProject
    case editProject(UUID)
}
