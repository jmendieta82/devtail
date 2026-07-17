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
    @State private var workspaceHolder: WorkspaceSessionsHolder
    @State private var appSettings: AppSettings
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let container = PersistenceController.makeContainer()
        let repository = ProjectRepository(context: container.mainContext)
        let quickLinkRepository = QuickLinkRepository(context: container.mainContext)
        let workspacePaneRepository = WorkspacePaneRepository(context: container.mainContext)
        // One-shot: retire legacy "claude" seed panes (see LegacyClaudePaneMigration).
        // Best-effort — a failure here must never block app launch.
        try? LegacyClaudePaneMigration.run(context: container.mainContext)
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

        let settings = AppSettings()
        _appSettings = State(initialValue: settings)

        let holder = WorkspaceSessionsHolder(
            engine: SwiftTermEngine { TerminalAppearance(settings: settings) },
            browserLauncher: browserLauncher,
            settings: settings
        )
        _workspaceHolder = State(initialValue: holder)
        AppDelegate.workspaceHolder = holder
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView()
                .id(appSettings.uiFontSize)
        } label: {
            Image(systemName: "terminal.fill")
        }
        .menuBarExtraStyle(.window)
        .modelContainer(modelContainer)
        .environment(projectStore)
        .environment(workspaceHolder)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: WindowID.newProject)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Window("New Project", id: WindowID.newProject) {
            NewProjectWindowView()
                .id(appSettings.uiFontSize)
        }
        .modelContainer(modelContainer)
        .environment(projectStore)
        .environment(appSettings)
        .defaultSize(width: 680, height: 620)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

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
                    .id(appSettings.uiFontSize)
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
    static let workspace = "devtail.workspace"
    static let newProject = "devtail.newProject"
}

/// Quit-time teardown. SwiftUI has no reliable "app will quit" hook for
/// scene-owned state, so the holder is bridged through a static.
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var workspaceHolder: WorkspaceSessionsHolder?

    func applicationWillTerminate(_ notification: Notification) {
        AppDelegate.workspaceHolder?.shutdownAll()
    }
}
