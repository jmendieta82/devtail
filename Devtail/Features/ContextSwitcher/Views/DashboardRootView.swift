//
//  DashboardRootView.swift
//  Devtail
//
//  Root view of the desktop dashboard window. Sidebar with project list
//  on the left (using DashboardSidebarItem), a mode-driven detail pane
//  on the right:
//
//    .browsing              → DashboardDetailView or empty state
//    .creatingProject       → ProjectFormView inline
//

import SwiftUI
import SwiftData

struct DashboardRootView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(WorkspaceSessionsHolder.self) private var workspaceHolder

    @State private var selectedProjectID: UUID?
    @State private var mode: DashboardMode = .browsing
    @State private var isFormDirty: Bool = false
    @State private var pendingSelection: UUID?
    @State private var searchQuery: String = ""
    @State private var sortMode: SidebarSortMode = SidebarSortMode.load()

    private let filterEngine = ProjectFilterEngine()

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(
                    min: DevtailTokens.Sizes.sidebarWidth,
                    ideal: DevtailTokens.Sizes.sidebarWidth,
                    max: DevtailTokens.Sizes.sidebarWidth
                )
        } detail: {
            detail
        }
        .frame(
            minWidth: DevtailTokens.Sizes.dashboardWidth,
            idealWidth: DevtailTokens.Sizes.dashboardWidth,
            maxWidth: DevtailTokens.Sizes.dashboardWidth,
            minHeight: DevtailTokens.Sizes.dashboardHeight,
            idealHeight: DevtailTokens.Sizes.dashboardHeight,
            maxHeight: DevtailTokens.Sizes.dashboardHeight
        )
        .containerBackground(dashboardBackground, for: .window)
        .navigationTitle("")
        .toolbar(removing: .title)
        .task {
            store.loadProjects()
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

    // MARK: - Background

    /// Dark gradient backdrop for the dashboard window.
    /// Top-left to bottom-right: near-black → deep indigo → accent teal.
    /// Gives the window a distinctive, futuristic look without relying on
    /// the system's translucent material (which picks up desktop noise).
    private var dashboardBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.09),
                Color(red: 0.08, green: 0.09, blue: 0.18),
                Color(red: 0.06, green: 0.14, blue: 0.22)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
    }

    private var sidebarHeader: some View {
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            Text("PROJECTS")
                .font(DevtailTokens.Typography.captionSmall)
                .tracking(0.5)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
            Spacer()
            if !store.projects.isEmpty {
                Text(headerCountText)
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textMuted)
                    .monospacedDigit()

                sortMenuButton
            }
        }
        .padding(.horizontal, DevtailTokens.Spacing.sidebarItemPadding)
        .padding(.top, DevtailTokens.Spacing.gapSection)
        .padding(.bottom, DevtailTokens.Spacing.gapMedium)
    }

    private var sortMenuButton: some View {
        Menu {
            Button {
                applySortMode(.recency)
            } label: {
                Label(
                    "By recency",
                    systemImage: sortMode == .recency ? "checkmark" : ""
                )
            }
            Button {
                applySortMode(.alphabetical)
            } label: {
                Label(
                    "By name",
                    systemImage: sortMode == .alphabetical ? "checkmark" : ""
                )
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(DevtailTokens.Typography.captionSmall)
                .foregroundStyle(DevtailTokens.Colors.textMuted)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Sort projects")
    }

    private func applySortMode(_ newSort: SidebarSortMode) {
        sortMode = newSort
        newSort.save()
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
            GlassEffectContainer {
                LazyVStack(spacing: DevtailTokens.Spacing.gapSmall) {
                    ForEach(filteredProjects, id: \.id) { project in
                        DashboardSidebarItem(
                            project: project,
                            isSelected: selectedProjectID == project.id,
                            isActive: workspaceHolder.isOpen(project.id)
                        )
                        .onTapGesture { requestSelection(project.id) }
                        .contextMenu {
                            Button {
                                store.openInVSCode(project: project)
                            } label: {
                                Label("Open in VSCode", systemImage: "chevron.left.forwardslash.chevron.right")
                            }
                        }
                    }
                }
                .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
                .padding(.bottom, DevtailTokens.Spacing.gapLarge)
            }
        }
        .scrollIndicators(.never)
    }

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
        Button {
            startCreating()
        } label: {
            HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                Image(systemName: "plus")
                Text("New project")
            }
            .font(DevtailTokens.Typography.bodySemibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DevtailTokens.Spacing.gapMedium)
            .background(
                RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                    .fill(DevtailTokens.Colors.accentPrimary)
            )
        }
        .buttonStyle(.plain)
        .help("New project")
        .padding(.horizontal, DevtailTokens.Spacing.sidebarItemPadding)
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
            .id("project-form-create")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var browsingContent: some View {
        if let project = currentProject {
            DashboardDetailView(
                project: project,
                onDeleteProject: { project in store.deleteProject(project) }
            )
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
            Text("Pick a project from the sidebar to manage its workspace and quick links.")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Mode transitions

    private func startCreating() {
        isFormDirty = false
        mode = .creatingProject
    }

    private func exitFormMode() {
        isFormDirty = false
        mode = .browsing
    }

    private func requestSelection(_ id: UUID) {
        switch mode {
        case .browsing:
            selectedProjectID = id

        case .creatingProject:
            if isFormDirty {
                pendingSelection = id
            } else {
                commitPendingSelection(id)
            }
        }
    }

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

    private var filteredProjects: [Project] {
        let base = filterEngine.filter(projects: store.projects, query: searchQuery)
        return sorted(base)
    }

    private func sorted(_ projects: [Project]) -> [Project] {
        switch sortMode {
        case .alphabetical:
            return projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .recency:
            return projects.sorted { a, b in
                switch (a.lastLaunchedAt, b.lastLaunchedAt) {
                case let (.some(dateA), .some(dateB)):
                    return dateA > dateB
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }
            }
        }
    }

    private var hasNoSearchResults: Bool {
        !store.projects.isEmpty
            && !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && filteredProjects.isEmpty
    }

    private func clearSelectionIfStale(_ newProjects: [Project]) {
        guard let id = selectedProjectID else { return }
        if !newProjects.contains(where: { $0.id == id }) {
            selectedProjectID = nil
        }
    }

}

/// The two modes the dashboard's right pane can be in.
enum DashboardMode: Equatable {
    case browsing
    case creatingProject
}
