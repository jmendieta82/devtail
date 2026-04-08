//
//  MenuBarRootView.swift
//  Devtail
//
//  Root view rendered inside the MenuBarExtra popover. Tabs header,
//  conditional search, custom-rendered project list with hover and
//  selection states, footer with Settings and Quit.
//

import SwiftUI
import SwiftData

struct MenuBarRootView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    @State private var selectedTab: ContextSwitcherTab = .projects
    @State private var searchQuery: String = ""
    @State private var selectedProjectID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // ─── Header ───
            HStack(alignment: .center, spacing: DevtailTokens.Spacing.gapMedium) {
                Text("Devtail")
                    .font(DevtailTokens.Typography.titleMedium)
                    .foregroundStyle(DevtailTokens.Colors.textPrimary)
                Spacer()
                TabHeader(selectedTab: $selectedTab)
                Button {
                    openCreateForm()
                } label: {
                    Image(systemName: "plus")
                        .font(DevtailTokens.Typography.bodyDefault)
                        .foregroundStyle(DevtailTokens.Colors.textSecondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("New project (⌘N)")
            }
            .padding(.horizontal, DevtailTokens.Spacing.popoverPadding)
            .padding(.top, DevtailTokens.Spacing.popoverPadding)

            // ─── Search (only when not empty) ───
            if !store.projects.isEmpty {
                SearchField(text: $searchQuery)
                    .padding(.horizontal, DevtailTokens.Spacing.popoverPadding)
                    .padding(.top, DevtailTokens.Spacing.gapMedium)
            }

            // ─── Content ───
            if store.projects.isEmpty {
                EmptyProjectsView(onCreate: openCreateForm)
                    .padding(.horizontal, DevtailTokens.Spacing.popoverPadding)
            } else {
                ScrollView {
                    LazyVStack(spacing: DevtailTokens.Spacing.gapSmall) {
                        ForEach(filteredProjects, id: \.id) { project in
                            ProjectRowView(
                                name: project.name,
                                color: project.color,
                                environment: project.environment,
                                stack: project.stack,
                                isSelected: selectedProjectID == project.id,
                                isInteractive: true,
                                onTap: { selectedProjectID = project.id },
                                onEdit: { openEditForm(for: project.id) },
                                onDelete: { store.deleteProject(project) }
                            )
                        }
                    }
                    .padding(.horizontal, DevtailTokens.Spacing.popoverPadding)
                    .padding(.top, DevtailTokens.Spacing.gapMedium)
                    .padding(.bottom, DevtailTokens.Spacing.gapMedium)
                }
                .frame(maxHeight: 360)
            }

            Divider()
                .padding(.top, DevtailTokens.Spacing.gapSmall)

            // ─── Footer ───
            HStack {
                Button {
                    openWindow(id: WindowID.settings)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .font(DevtailTokens.Typography.bodySmall)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal, DevtailTokens.Spacing.popoverPadding)
            .padding(.vertical, DevtailTokens.Spacing.gapMedium)
        }
        .frame(width: DevtailTokens.Sizes.popoverWidth)
        .background(DevtailTokens.Colors.popoverBackground)
        .task { store.loadProjects() }
        .onChange(of: store.projects) { _, newProjects in
            clearSelectionIfStale(newProjects)
        }
    }

    private var filteredProjects: [Project] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return store.projects }
        let needle = trimmed.lowercased()
        return store.projects.filter { project in
            project.name.lowercased().contains(needle) ||
            (project.stack?.lowercased().contains(needle) ?? false)
        }
    }

    private func openCreateForm() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: WindowID.projectForm, value: UUID?.none)
    }

    private func openEditForm(for projectID: UUID) {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: WindowID.projectForm, value: Optional(projectID))
    }

    private func clearSelectionIfStale(_ newProjects: [Project]) {
        guard let id = selectedProjectID else { return }
        if !newProjects.contains(where: { $0.id == id }) {
            selectedProjectID = nil
        }
    }
}

#Preview("Empty state") {
    let store: ProjectStore = {
        let container = PersistenceController.makeContainer(inMemory: true)
        let repository = ProjectRepository(context: container.mainContext)
        return ProjectStore(repository: repository)
    }()
    MenuBarRootView()
        .environment(store)
}

#Preview("Populated") {
    let store: ProjectStore = {
        let container = PersistenceController.makeContainer(inMemory: true)
        let repository = ProjectRepository(context: container.mainContext)
        let store = ProjectStore(repository: repository)
        store.createProject(
            name: "Devtail",
            color: .green,
            environment: .dev,
            stack: "Swift"
        )
        store.createProject(
            name: "Side Project",
            color: .blue,
            environment: .staging,
            stack: "TypeScript"
        )
        store.createProject(
            name: "Pixel",
            color: .purple,
            environment: .prod,
            stack: "Rust"
        )
        return store
    }()
    MenuBarRootView()
        .environment(store)
}
