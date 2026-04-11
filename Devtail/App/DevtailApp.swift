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
    @State private var dashboardIntent = DashboardIntentHolder()
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
        .environment(dashboardIntent)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    NSApp.activate(ignoringOtherApps: true)
                    dashboardIntent.pending = .createProject
                    openWindow(id: WindowID.dashboard)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Window("Devtail", id: WindowID.dashboard) {
            DashboardRootView()
        }
        .modelContainer(modelContainer)
        .environment(projectStore)
        .environment(activityMonitor)
        .environment(dashboardIntent)
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

/// Intent the dashboard window should apply the next time it appears
/// or receives a new focus. Callers set `pending` before calling
/// `openWindow(id:)`; the dashboard reads it in `.task` and clears it.
@MainActor @Observable
final class DashboardIntentHolder {
    var pending: DashboardIntent = .none
}

enum DashboardIntent: Equatable {
    case none
    case createProject
    case editProject(UUID)
}
