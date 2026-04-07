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
    let modelContainer: ModelContainer = PersistenceController.makeContainer()

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView()
        } label: {
            Image(systemName: "terminal.fill")
        }
        .menuBarExtraStyle(.window)
        .modelContainer(modelContainer)

        Window("Devtail", id: WindowID.dashboard) {
            DashboardRootView()
        }
        .modelContainer(modelContainer)
        .windowResizability(.contentSize)
    }
}

enum WindowID {
    static let dashboard = "devtail.dashboard"
}
