//
//  DashboardRootView.swift
//  Devtail
//
//  Root view of the desktop dashboard window. Hosts the full project
//  management surface: sidebar with project list on the left, a mode-driven
//  panel on the right. The right panel morphs between three modes:
//
//    .browsing              → project detail (header + tabs + panels) or
//                             an empty state when nothing is selected
//    .creatingProject       → ProjectFormView inline, creating a new one
//    .editingProject(id)    → ProjectFormView inline, editing an existing
//
//  When the user taps a different project in the sidebar while in a form
//  mode WITH unsaved changes, we surface a native confirmation alert before
//  discarding. With no changes, the switch is silent and instant.
//

import SwiftUI
import SwiftData

struct DashboardRootView: View {
    @Environment(ProjectStore.self) private var store

    let initialIntent: DashboardIntent

    @State private var selectedProjectID: UUID?
    /// Workspace first by default — same reasoning as the popover:
    /// the primary action lives in the Workspace tab, so anchor there.
    @State private var selectedTab: DashboardDetailTab = .workspace
    @State private var mode: DashboardMode = .browsing
    @State private var isFormDirty: Bool = false
    @State private var pendingSelection: UUID?
    @State private var didApplyInitialIntent: Bool = false
    @State private var searchQuery: String = ""

    /// Same engine instance as the menubar uses. Stateless, so a fresh
    /// `let` is fine — SwiftUI will not recreate it on body re-renders.
    private let filterEngine = ProjectFilterEngine()

    init(initialIntent: DashboardIntent = .none) {
        self.initialIntent = initialIntent
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(
                    min: DevtailTokens.Sizes.sidebarWidth,
                    ideal: DevtailTokens.Sizes.sidebarWidth + 40,
                    max: 320
                )
        } detail: {
            detail
        }
        .frame(
            minWidth: DevtailTokens.Sizes.dashboardWidth,
            minHeight: DevtailTokens.Sizes.dashboardHeight
        )
        .background(DevtailTokens.Colors.appBackground)
        .navigationTitle("")
        .toolbar(removing: .title)
        .task {
            store.loadProjects()
            applyInitialIntentIfNeeded()
        }
        .onChange(of: store.projects) { _, newProjects in
            clearSelectionIfStale(newProjects)
        }
        .alert(
            "Discard changes?",
            isPresented: Binding(
                get: { pendingSelection != nil },
                set: { if !$0 { pendingSelection = nil } }
            ),
            presenting: pendingSelection
        ) { targetID in
            Button("Keep Editing", role: .cancel) {
                pendingSelection = nil
            }
            Button("Discard", role: .destructive) {
                commitPendingSelection(targetID)
            }
        } message: { _ in
            Text("You have unsaved changes in the project form. Switching projects will lose them.")
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader

            if !store.projects.isEmpty {
                SearchField(text: $searchQuery)
                    .padding(.horizontal, DevtailTokens.Spacing.sidebarItemPadding)
                    .padding(.bottom, DevtailTokens.Spacing.gapMedium)
            }

            if store.projects.isEmpty {
                sidebarEmptyState
            } else if hasNoSearchResults {
                sidebarNoResultsState
            } else {
                sidebarList
            }

            Divider()
            sidebarFooter
        }
        .background(DevtailTokens.Colors.sidebar)
    }

    private var sidebarHeader: some View {
        HStack {
            Text("PROJECTS")
                .font(DevtailTokens.Typography.captionSmall)
                .tracking(0.5)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
            Spacer()
            if !store.projects.isEmpty {
                // When a search is active, show "matched/total" so the
                // user can see at a glance how aggressive the filter is.
                // No active query → just the total, like before.
                Text(headerCountText)
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textMuted)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, DevtailTokens.Spacing.sidebarItemPadding)
        .padding(.top, DevtailTokens.Spacing.gapSection)
        .padding(.bottom, DevtailTokens.Spacing.gapMedium)
    }

    private var headerCountText: String {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "\(store.projects.count)"
        }
        return "\(filteredProjects.count)/\(store.projects.count)"
    }

    private var sidebarEmptyState: some View {
        VStack(spacing: DevtailTokens.Spacing.gapMedium) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
            Text("No projects yet")
                .font(DevtailTokens.Typography.bodyDefault)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Text("Create your first project to get started.")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DevtailTokens.Spacing.gapLarge)
            Button {
                startCreating()
            } label: {
                Label("New project", systemImage: "plus")
                    .font(DevtailTokens.Typography.bodySmall)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, DevtailTokens.Spacing.gapSmall)
            Spacer()
        }
    }

    private var sidebarList: some View {
        ScrollView {
            LazyVStack(spacing: DevtailTokens.Spacing.gapSmall) {
                ForEach(filteredProjects, id: \.id) { project in
                    ProjectRowView(
                        name: project.name,
                        color: project.color,
                        isSelected: selectedProjectID == project.id,
                        isInteractive: true,
                        onTap: { requestSelection(project.id) },
                        onEdit: { startEditing(project.id) },
                        onDelete: { store.deleteProject(project) }
                    )
                }
            }
            .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
            .padding(.bottom, DevtailTokens.Spacing.gapLarge)
        }
    }

    /// Sidebar empty state shown when the user typed a query that no
    /// project matches. Mirrors the menubar's `noSearchResultsView`
    /// shape but uses sidebar-friendly typography and includes a button
    /// to clear the filter — the dashboard has more room than the
    /// popover does, so we can afford the affordance.
    private var sidebarNoResultsState: some View {
        VStack(spacing: DevtailTokens.Spacing.gapMedium) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
            Text("No matches")
                .font(DevtailTokens.Typography.bodyDefault)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Text("\u{201C}\(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines))\u{201D}")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, DevtailTokens.Spacing.gapLarge)
            Button("Clear search") {
                searchQuery = ""
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, DevtailTokens.Spacing.gapSmall)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var sidebarFooter: some View {
        HStack {
            Button {
                startCreating()
            } label: {
                HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                    Image(systemName: "plus")
                    Text("New project")
                }
                .font(DevtailTokens.Typography.bodySmall)
                .foregroundStyle(DevtailTokens.Colors.accentGreen)
                .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
                .padding(.vertical, DevtailTokens.Spacing.gapSmall)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)
            .help("New project (⌘N)")

            Spacer()
        }
        .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
        .padding(.vertical, DevtailTokens.Spacing.gapMedium)
    }

    // MARK: - Detail (mode-driven)

    @ViewBuilder
    private var detail: some View {
        switch mode {
        case .browsing:
            browsingContent
        case .creatingProject:
            ProjectFormView(
                projectID: nil,
                onDismiss: { exitFormMode() },
                isDirty: $isFormDirty
            )
            .environment(store)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DevtailTokens.Colors.appBackground)
        case .editingProject(let id):
            ProjectFormView(
                projectID: id,
                onDismiss: { exitFormMode() },
                isDirty: $isFormDirty
            )
            .environment(store)
            .id(id) // Force re-init when switching between different projects.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DevtailTokens.Colors.appBackground)
        }
    }

    @ViewBuilder
    private var browsingContent: some View {
        if let project = currentProject {
            projectDetail(project)
        } else {
            noSelectionState
        }
    }

    private var noSelectionState: some View {
        VStack(spacing: DevtailTokens.Spacing.gapLarge) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
            Text("Select a project")
                .font(DevtailTokens.Typography.titleMedium)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Text("Pick a project from the sidebar to manage its quick links and workspace panes.")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DevtailTokens.Colors.appBackground)
    }

    @ViewBuilder
    private func projectDetail(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            detailHeader(project)
            Divider()
            detailTabBar
            Divider()
            detailTabContent(project)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DevtailTokens.Colors.appBackground)
    }

    private func detailHeader(_ project: Project) -> some View {
        HStack(alignment: .top, spacing: DevtailTokens.Spacing.gapLarge) {
            ColorDot(color: project.color, size: DevtailTokens.Sizes.projectDotLarge)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
                Text(project.name)
                    .font(DevtailTokens.Typography.titleLarge)
                    .foregroundStyle(DevtailTokens.Colors.textPrimary)

                HStack(spacing: DevtailTokens.Spacing.gapMedium) {
                    Text("\(project.quickLinks.count) link\(project.quickLinks.count == 1 ? "" : "s")")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    metadataDot
                    Text("\(project.workspacePanes.count) pane\(project.workspacePanes.count == 1 ? "" : "s")")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                }

                if !project.directoryPath.isEmpty {
                    Text(project.directoryPath)
                        .font(DevtailTokens.Typography.monoSmall)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Button {
                startEditing(project.id)
            } label: {
                HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                    Image(systemName: "pencil")
                    Text("Edit")
                }
                .font(DevtailTokens.Typography.bodySmall)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Edit project details")
        }
        .padding(.horizontal, DevtailTokens.Spacing.dashboardPadding)
        .padding(.top, DevtailTokens.Spacing.gapLarge)
        .padding(.bottom, DevtailTokens.Spacing.gapSection)
    }

    private var metadataDot: some View {
        Circle()
            .fill(DevtailTokens.Colors.textMuted)
            .frame(width: 3, height: 3)
    }

    private var detailTabBar: some View {
        HStack(spacing: 0) {
            // WORKSPACE first — matches the menubar popover ordering and
            // puts the primary launch action one click away.
            dashboardTabButton(title: "WORKSPACE",   tab: .workspace)
            dashboardTabButton(title: "QUICK LINKS", tab: .quickLinks)
            Spacer()
        }
        .padding(.horizontal, DevtailTokens.Spacing.dashboardPadding)
        .padding(.top, DevtailTokens.Spacing.gapMedium)
        .padding(.bottom, DevtailTokens.Spacing.gapSmall)
    }

    @ViewBuilder
    private func dashboardTabButton(title: String, tab: DashboardDetailTab) -> some View {
        let isSelected = selectedTab == tab
        Button {
            selectedTab = tab
        } label: {
            Text(title)
                .font(DevtailTokens.Typography.captionSmall)
                .tracking(0.5)
                .foregroundStyle(
                    isSelected
                        ? DevtailTokens.Colors.accentGreen
                        : DevtailTokens.Colors.textTertiary
                )
                .padding(.horizontal, DevtailTokens.Spacing.gapLarge)
                .padding(.vertical, DevtailTokens.Spacing.gapMedium)
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Rectangle()
                            .fill(DevtailTokens.Colors.accentGreen)
                            .frame(height: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func detailTabContent(_ project: Project) -> some View {
        switch selectedTab {
        case .quickLinks:
            QuickLinksPanel(projectID: project.id)
        case .workspace:
            WorkspacePanel(projectID: project.id)
        }
    }

    // MARK: - Mode transitions

    private func startCreating() {
        // Enter create mode. If the user was already editing/creating with
        // dirty changes, we would lose them — but startCreating() is only
        // invoked from explicit affordances ("+ New project"), which in the
        // current UI are not reachable while a form is active (the right
        // pane IS the form). No guard needed today.
        isFormDirty = false
        mode = .creatingProject
    }

    private func startEditing(_ id: UUID) {
        selectedProjectID = id
        isFormDirty = false
        mode = .editingProject(id)
    }

    private func exitFormMode() {
        isFormDirty = false
        mode = .browsing
    }

    /// Called when the user taps a project in the sidebar. In browsing mode
    /// this is a plain selection. In a form mode it depends on dirty state:
    /// clean forms switch silently, dirty forms prompt for confirmation.
    private func requestSelection(_ id: UUID) {
        switch mode {
        case .browsing:
            selectedProjectID = id

        case .creatingProject, .editingProject:
            if isFormDirty {
                pendingSelection = id
            } else {
                commitPendingSelection(id)
            }
        }
    }

    /// Applies a selection the user requested mid-form. Used both by the
    /// "clean switch" fast path and by the "Discard" branch of the alert.
    private func commitPendingSelection(_ id: UUID) {
        pendingSelection = nil
        isFormDirty = false
        selectedProjectID = id
        mode = .browsing
    }

    // MARK: - Helpers

    private var currentProject: Project? {
        guard let id = selectedProjectID else { return nil }
        return store.projects.first { $0.id == id }
    }

    /// Project list filtered through the shared engine. The selection
    /// itself (`selectedProjectID`) is intentionally NOT cleared when
    /// the filter hides a project — switching projects via search and
    /// then clearing the search should bring the selection back into
    /// view, not lose it.
    private var filteredProjects: [Project] {
        filterEngine.filter(projects: store.projects, query: searchQuery)
    }

    /// True when there ARE projects in the store but the active query
    /// filtered them all out. Distinct from "no projects exist" which
    /// is handled by `sidebarEmptyState`.
    private var hasNoSearchResults: Bool {
        !store.projects.isEmpty
            && !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && filteredProjects.isEmpty
    }

    private func clearSelectionIfStale(_ newProjects: [Project]) {
        guard let id = selectedProjectID else { return }
        if !newProjects.contains(where: { $0.id == id }) {
            selectedProjectID = nil
            // If the project we were editing got deleted elsewhere, bail out
            // of the form — its target no longer exists.
            if case .editingProject(let editingID) = mode, editingID == id {
                exitFormMode()
            }
        }
    }

    /// Applies the intent the window was opened with, but only the first time
    /// the view appears. Without this guard, re-selecting the window from the
    /// dock after closing would re-trigger the intent, which is surprising.
    private func applyInitialIntentIfNeeded() {
        guard !didApplyInitialIntent else { return }
        didApplyInitialIntent = true
        switch initialIntent {
        case .none:
            break
        case .createProject:
            startCreating()
        case .editProject(let id):
            startEditing(id)
        }
    }
}

enum DashboardDetailTab {
    case quickLinks
    case workspace
}

/// The three modes the dashboard's right pane can be in. Swapping between
/// them replaces the content of the detail pane inline — no sheets, no
/// separate windows.
enum DashboardMode: Equatable {
    case browsing
    case creatingProject
    case editingProject(UUID)
}

#Preview("Empty") {
    let store: ProjectStore = {
        let container = PersistenceController.makeContainer(inMemory: true)
        let projectRepo = ProjectRepository(context: container.mainContext)
        let linkRepo = QuickLinkRepository(context: container.mainContext)
        let paneRepo = WorkspacePaneRepository(context: container.mainContext)
        return ProjectStore(
            repository: projectRepo,
            quickLinkRepository: linkRepo,
            workspacePaneRepository: paneRepo,
            launcher: WorkspaceLauncher()
        )
    }()
    DashboardRootView()
        .environment(store)
        .preferredColorScheme(.dark)
}

#Preview("Populated") {
    let store: ProjectStore = {
        let container = PersistenceController.makeContainer(inMemory: true)
        let projectRepo = ProjectRepository(context: container.mainContext)
        let linkRepo = QuickLinkRepository(context: container.mainContext)
        let paneRepo = WorkspacePaneRepository(context: container.mainContext)
        let store = ProjectStore(
            repository: projectRepo,
            quickLinkRepository: linkRepo,
            workspacePaneRepository: paneRepo,
            launcher: WorkspaceLauncher()
        )
        store.createProject(name: "Devtail", color: .green)
        store.createProject(name: "Side Project", color: .blue)
        store.createProject(name: "Pixel", color: .purple)
        if let project = store.projects.first {
            store.addQuickLink(label: "GitHub", url: "https://github.com", to: project)
            store.addQuickLink(label: "Notion", url: "https://notion.so", to: project)
        }
        return store
    }()
    DashboardRootView()
        .environment(store)
        .preferredColorScheme(.dark)
}
