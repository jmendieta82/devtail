//
//  MenuBarRootView.swift
//  Devtail
//
//  Root view rendered inside the MenuBarExtra popover.
//  Renders the live project list, the empty-state CTA, and the
//  "New Project" / "Dashboard" / "Quit" action bar.
//

import SwiftUI
import SwiftData

struct MenuBarRootView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            if store.projects.isEmpty {
                ContentUnavailableView {
                    Label("No projects yet", systemImage: "folder.badge.plus")
                } description: {
                    Text("Create your first project to get started.")
                } actions: {
                    Button("Create your first project") {
                        openWindow(id: WindowID.newProject)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                List {
                    ForEach(store.projects, id: \.id) { project in
                        Label(project.name, systemImage: "folder")
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    store.deleteProject(project)
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: 320)
            }

            Divider()

            HStack {
                Button("New Project") {
                    openWindow(id: WindowID.newProject)
                }

                Spacer()

                Button("Dashboard") {
                    openWindow(id: WindowID.dashboard)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
        .task {
            store.loadProjects()
        }
    }
}

#Preview("Empty state") {
    let container = PersistenceController.makeContainer(inMemory: true)
    let repository = ProjectRepository(context: container.mainContext)
    let store = ProjectStore(repository: repository)
    MenuBarRootView()
        .environment(store)
}

#Preview("Populated") {
    let store: ProjectStore = {
        let container = PersistenceController.makeContainer(inMemory: true)
        let repository = ProjectRepository(context: container.mainContext)
        let store = ProjectStore(repository: repository)
        store.createProject(name: "Devtail", notes: "Menu bar app")
        store.createProject(name: "Side Project", notes: nil)
        return store
    }()
    MenuBarRootView()
        .environment(store)
}
