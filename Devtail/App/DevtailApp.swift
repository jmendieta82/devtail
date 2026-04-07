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

    init() {
        let container = PersistenceController.makeContainer()
        let repository = ProjectRepository(context: container.mainContext)
        let store = ProjectStore(repository: repository)
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

        Window("Devtail", id: WindowID.dashboard) {
            DashboardRootView()
        }
        .modelContainer(modelContainer)
        .environment(projectStore)
        .windowResizability(.contentSize)

        Window("New Project", id: WindowID.newProject) {
            NewProjectView()
        }
        .modelContainer(modelContainer)
        .environment(projectStore)
        .windowResizability(.contentSize)
        .defaultSize(width: 360, height: 280)
    }
}

enum WindowID {
    static let dashboard = "devtail.dashboard"
    static let newProject = "devtail.newProject"
}
