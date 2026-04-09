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

    /// Index into `filteredProjects` representing the keyboard cursor.
    /// `nil` means "no row currently focused by keyboard" — in that case
    /// the first ↓ key press selects index 0. Reset whenever the
    /// filtered list changes so we never point at a stale row.
    @State private var keyboardSelectedIndex: Int? = nil

    /// Stateless filter engine shared with the dashboard. Held as a
    /// constant so SwiftUI does not recreate it on every body eval.
    private let filterEngine = ProjectFilterEngine()

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
            } else if hasNoSearchResults {
                // Search active but the filter killed every project. We
                // keep the same vertical footprint as the populated list
                // so the popover doesn't jump in size as the user types.
                noSearchResultsView
                    .frame(height: DevtailTokens.Sizes.projectListHeight)

                Divider()

                DetailPanel(
                    projectID: selectedProjectID,
                    isReadOnly: true,
                    onEditProject: openDashboardForEdit
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: DevtailTokens.Spacing.gapSmall) {
                            ForEach(Array(filteredProjects.enumerated()), id: \.element.id) { index, project in
                                ProjectRowView(
                                    name: project.name,
                                    color: project.color,
                                    isSelected: selectedProjectID == project.id,
                                    isKeyboardFocused: keyboardSelectedIndex == index,
                                    isInteractive: true,
                                    onTap: {
                                        selectedProjectIDString = project.id.uuidString
                                    },
                                    onEdit: nil,
                                    onDelete: nil
                                )
                                .id(project.id)
                            }
                        }
                        .padding(.horizontal, DevtailTokens.Spacing.popoverPadding)
                        .padding(.top, DevtailTokens.Spacing.gapMedium)
                        .padding(.bottom, DevtailTokens.Spacing.gapMedium)
                    }
                    .frame(height: DevtailTokens.Sizes.projectListHeight)
                    .onChange(of: keyboardSelectedIndex) { _, newIndex in
                        guard let newIndex,
                              filteredProjects.indices.contains(newIndex) else { return }
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(filteredProjects[newIndex].id, anchor: .center)
                        }
                    }
                }

                Divider()

                DetailPanel(
                    projectID: selectedProjectID,
                    isReadOnly: true,
                    onEditProject: openDashboardForEdit
                )
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
            // Filtered list mirrors the source — collapse the cursor.
            keyboardSelectedIndex = nil
        }
        .onChange(of: searchQuery) { _, _ in
            // Any change to the query collapses the cursor: even if a
            // row was selected, its index in the *new* filtered list
            // is meaningless. Down-arrow re-anchors at index 0.
            keyboardSelectedIndex = nil
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.downArrow) {
            moveKeyboardCursor(by: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveKeyboardCursor(by: -1)
            return .handled
        }
        .onKeyPress(.return) {
            commitKeyboardSelection()
        }
        .onKeyPress(.escape) {
            handleEscape()
        }
    }

    // MARK: - Keyboard navigation

    /// Moves the keyboard cursor by `delta` rows, clamping at the ends
    /// of the filtered list. Pressing ↓ from "no cursor" lands on row 0;
    /// pressing ↑ from "no cursor" lands on the last row (matches how
    /// most native macOS lists behave when first opened).
    private func moveKeyboardCursor(by delta: Int) {
        let count = filteredProjects.count
        guard count > 0 else { return }

        let next: Int
        if let current = keyboardSelectedIndex {
            next = max(0, min(count - 1, current + delta))
        } else {
            next = delta > 0 ? 0 : count - 1
        }
        keyboardSelectedIndex = next
    }

    /// Commits the keyboard cursor to the persistent selection. If no
    /// row is cursored, Enter is a no-op (we don't want to randomly
    /// open the first project just because the user hit Return without
    /// navigating first).
    private func commitKeyboardSelection() -> KeyPress.Result {
        guard let index = keyboardSelectedIndex,
              filteredProjects.indices.contains(index) else {
            return .ignored
        }
        let project = filteredProjects[index]
        selectedProjectIDString = project.id.uuidString
        return .handled
    }

    /// Esc behavior: clear the search query if there is one. Otherwise
    /// just collapse the cursor without intercepting the key — the
    /// system can decide whether to dismiss the popover.
    private func handleEscape() -> KeyPress.Result {
        if !searchQuery.isEmpty {
            searchQuery = ""
            keyboardSelectedIndex = nil
            return .handled
        }
        keyboardSelectedIndex = nil
        return .ignored
    }

    private var filteredProjects: [Project] {
        filterEngine.filter(projects: store.projects, query: searchQuery)
    }

    /// Friendly empty state shown when the user typed a query that
    /// matches no projects. Mirrors the visual rhythm of the populated
    /// list (centered, muted, no extra chrome) so the popover stays calm.
    @ViewBuilder
    private var noSearchResultsView: some View {
        VStack(spacing: DevtailTokens.Spacing.gapMedium) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
            Text("No projects matching")
                .font(DevtailTokens.Typography.bodySmall)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Text("\u{201C}\(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines))\u{201D}")
                .font(DevtailTokens.Typography.bodySmall.weight(.semibold))
                .foregroundStyle(DevtailTokens.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, DevtailTokens.Spacing.popoverPadding)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// True when the user has typed something but no project matches it.
    /// Different from "no projects exist at all" — that case is handled
    /// by `EmptyProjectsView` higher up.
    private var hasNoSearchResults: Bool {
        !store.projects.isEmpty
            && !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && filteredProjects.isEmpty
    }

    private func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: WindowID.dashboard, value: DashboardIntent.none)
    }

    private func openDashboardForCreate() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: WindowID.dashboard, value: DashboardIntent.createProject)
    }

    /// Opens the dashboard window with the given project pre-selected
    /// in edit mode. Wired into the read-only DetailPanel's "Edit"
    /// affordance — clicking it lifts the user out of the popover and
    /// into the full editor surface where panes and links can be
    /// modified properly.
    private func openDashboardForEdit(_ projectID: UUID) {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: WindowID.dashboard, value: DashboardIntent.editProject(projectID))
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
            color: .green
        )
        store.createProject(
            name: "Side Project",
            color: .blue
        )
        store.createProject(
            name: "Pixel",
            color: .purple
        )
        return store
    }()
    MenuBarRootView()
        .environment(store)
}
