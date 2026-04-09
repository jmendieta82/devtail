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
                .preferredColorScheme(.dark)
        } label: {
            Image(systemName: "terminal.fill")
        }
        .menuBarExtraStyle(.window)
        .modelContainer(modelContainer)
        .environment(projectStore)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: WindowID.projectForm, value: UUID?.none)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Window("Devtail", id: WindowID.dashboard) {
            DashboardRootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
        .environment(projectStore)
        .windowResizability(.contentSize)

        WindowGroup("Project", id: WindowID.projectForm, for: UUID?.self) { $projectID in
            ProjectFormView(projectID: projectID ?? nil)
                .preferredColorScheme(.dark)
        } defaultValue: {
            nil
        }
        .modelContainer(modelContainer)
        .environment(projectStore)
        .windowResizability(.contentSize)
        .defaultSize(width: 460, height: 580)

        Window("Settings", id: WindowID.settings) {
            ComingSoonView(title: "Settings")
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 300)
    }
}

enum WindowID {
    static let dashboard   = "devtail.dashboard"
    static let projectForm = "devtail.projectForm"
    static let settings    = "devtail.settings"
}
