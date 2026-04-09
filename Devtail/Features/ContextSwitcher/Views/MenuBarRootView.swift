//
//  MenuBarRootView.swift
//  Devtail
//
//  Root view rendered inside the MenuBarExtra popover. Tabs header,
//  conditional search, master-detail layout (project list + QuickLinksPanel),
//  footer with Settings and Quit.
//

import SwiftUI
import SwiftData

struct MenuBarRootView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    @State private var selectedTab: ContextSwitcherTab = .projects
    @State private var searchQuery: String = ""

    /// Stored as String because @AppStorage doesn't support UUID? natively.
    /// Read via the `selectedProjectID` computed property.
    @AppStorage("devtail.selectedProjectID") private var selectedProjectIDString: String = ""

    private var selectedProjectID: UUID? {
        UUID(uuidString: selectedProjectIDString)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ─── Header ───
            HStack(alignment: .center, spacing: DevtailTokens.Spacing.gapMedium) {
                Text("Devtail")
                    .font(DevtailTokens.Typography.titleMedium)
                    .foregroundStyle(DevtailTokens.Colors.textPrimary)
                Spacer()
                TabHeader(selectedTab: $selectedTab)
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
                EmptyProjectsView(onCreate: openDashboardForCreate)
                    .padding(.horizontal, DevtailTokens.Spacing.popoverPadding)
            } else {
                ScrollView {
                    LazyVStack(spacing: DevtailTokens.Spacing.gapSmall) {
                        ForEach(filteredProjects, id: \.id) { project in
                            ProjectRowView(
                                name: project.name,
                                color: project.color,
                                environment: project.environment,
                                isSelected: selectedProjectID == project.id,
                                isInteractive: true,
                                onTap: {
                                    selectedProjectIDString = project.id.uuidString
                                },
                                onEdit: nil,
                                onDelete: nil
                            )
                        }
                    }
                    .padding(.horizontal, DevtailTokens.Spacing.popoverPadding)
                    .padding(.top, DevtailTokens.Spacing.gapMedium)
                    .padding(.bottom, DevtailTokens.Spacing.gapMedium)
                }
                .frame(height: DevtailTokens.Sizes.projectListHeight)

                Divider()

                DetailPanel(projectID: selectedProjectID)
            }

            Divider()
                .padding(.top, DevtailTokens.Spacing.gapSmall)

            // ─── Footer ───
            HStack(spacing: DevtailTokens.Spacing.gapLarge) {
                Button {
                    openDashboard()
                } label: {
                    Label("Manage…", systemImage: "square.grid.2x2")
                        .font(DevtailTokens.Typography.bodySmall)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
                .help("Open the Devtail dashboard")

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
            project.name.lowercased().contains(needle)
        }
    }

    private func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: WindowID.dashboard, value: DashboardIntent.none)
    }

    private func openDashboardForCreate() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: WindowID.dashboard, value: DashboardIntent.createProject)
    }

    private func clearSelectionIfStale(_ newProjects: [Project]) {
        guard let id = selectedProjectID else { return }
        if !newProjects.contains(where: { $0.id == id }) {
            selectedProjectIDString = ""
        }
    }
}

#Preview("Empty state") {
    let store: ProjectStore = {
        let container = PersistenceController.makeContainer(inMemory: true)
        let repository = ProjectRepository(context: container.mainContext)
        let linkRepository = QuickLinkRepository(context: container.mainContext)
        let paneRepository = WorkspacePaneRepository(context: container.mainContext)
        return ProjectStore(
            repository: repository,
            quickLinkRepository: linkRepository,
            workspacePaneRepository: paneRepository,
            launcher: WorkspaceLauncher()
        )
    }()
    MenuBarRootView()
        .environment(store)
}

#Preview("Populated") {
    let store: ProjectStore = {
        let container = PersistenceController.makeContainer(inMemory: true)
        let repository = ProjectRepository(context: container.mainContext)
        let linkRepository = QuickLinkRepository(context: container.mainContext)
        let paneRepository = WorkspacePaneRepository(context: container.mainContext)
        let store = ProjectStore(
            repository: repository,
            quickLinkRepository: linkRepository,
            workspacePaneRepository: paneRepository,
            launcher: WorkspaceLauncher()
        )
        store.createProject(
            name: "Devtail",
            color: .green,
            environment: .dev
        )
        store.createProject(
            name: "Side Project",
            color: .blue,
            environment: .staging
        )
        store.createProject(
            name: "Pixel",
            color: .purple,
            environment: .prod
        )
        return store
    }()
    MenuBarRootView()
        .environment(store)
}
