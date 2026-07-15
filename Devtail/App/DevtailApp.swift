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
    @State private var dashboardIntent = DashboardIntentHolder()
    @State private var workspaceHolder: WorkspaceSessionsHolder
    private let appSettings = AppSettings()
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let container = PersistenceController.makeContainer()
        let repository = ProjectRepository(context: container.mainContext)
        let quickLinkRepository = QuickLinkRepository(context: container.mainContext)
        let workspacePaneRepository = WorkspacePaneRepository(context: container.mainContext)
        let vscodeLauncher = VSCodeLauncher()
        let browserLauncher = BrowserLauncher()
        let store = ProjectStore(
            repository: repository,
            quickLinkRepository: quickLinkRepository,
            workspacePaneRepository: workspacePaneRepository,
            vscodeLauncher: vscodeLauncher,
            browserLauncher: browserLauncher
        )
        _modelContainer = State(initialValue: container)
        _projectStore = State(initialValue: store)

        let holder = WorkspaceSessionsHolder(
            engine: SwiftTermEngine(),
            browserLauncher: browserLauncher,
            settings: appSettings
        )
        _workspaceHolder = State(initialValue: holder)
        AppDelegate.workspaceHolder = holder
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
        .environment(dashboardIntent)
        .environment(workspaceHolder)
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
        .environment(dashboardIntent)
        .environment(workspaceHolder)
        .environment(appSettings)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

        Window("Settings", id: WindowID.settings) {
            ComingSoonView(title: "Settings")
        }
        .environment(appSettings)
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 300)

        WindowGroup("Workspace", id: WindowID.workspace, for: UUID.self) { $projectId in
            // If the project backing this window is deleted while the
            // workspace is open, this condition fails and the view renders
            // nothing. The resulting `onDisappear` (see WorkspaceRootView)
            // is what tears down its sessions via `holder.close(projectId:)`
            // — a coincidental but intended teardown trigger.
            if let projectId,
               let project = projectStore.projects.first(where: { $0.id == projectId }) {
                WorkspaceRootView(session: workspaceHolder.openSession(for: project))
                    .environment(workspaceHolder)
            }
        }
        .modelContainer(modelContainer)
        .environment(projectStore)
        .environment(appSettings)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 760)
    }
}

enum WindowID {
    static let dashboard = "devtail.dashboard"
    static let settings  = "devtail.settings"
    static let workspace = "devtail.workspace"
}

/// Quit-time teardown. SwiftUI has no reliable "app will quit" hook for
/// scene-owned state, so the holder is bridged through a static.
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var workspaceHolder: WorkspaceSessionsHolder?

    func applicationWillTerminate(_ notification: Notification) {
        AppDelegate.workspaceHolder?.shutdownAll()
    }
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
