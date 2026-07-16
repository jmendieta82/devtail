//
//  MenuBarRootView.swift
//  Devtail
//
//  Root view rendered inside the MenuBarExtra popover.
//  Single-column accordion layout — expand a project to see its panes
//  and launch. Zero configuration; all editing lives in the Dashboard.
//

import SwiftUI
import SwiftData

struct MenuBarRootView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(WorkspaceSessionsHolder.self) private var workspaceHolder
    @Environment(DashboardIntentHolder.self) private var intentHolder
    @Environment(\.openWindow) private var openWindow

    @State private var searchQuery: String = ""
    @State private var expandedProjectID: UUID? = nil
    @State private var keyboardSelectedIndex: Int? = nil

    private let filterEngine = ProjectFilterEngine()
    private let branchDetector = GitBranchDetector()

    var body: some View {
        VStack(spacing: 0) {
            // ─── Search ───
            if !store.projects.isEmpty {
                SearchField(text: $searchQuery)
                    .padding(.horizontal, DevtailTokens.Spacing.popoverPadding)
                    .padding(.top, DevtailTokens.Spacing.popoverPadding)
            }

            // ─── Content ───
            if store.projects.isEmpty {
                EmptyProjectsView(onCreate: openDashboardForCreate)
                    .padding(DevtailTokens.Spacing.popoverPadding)
            } else if hasNoSearchResults {
                noSearchResultsView
            } else {
                ScrollView {
                    LazyVStack(spacing: DevtailTokens.Spacing.gapMedium) {
                        ForEach(filteredProjects) { project in
                            PopoverAccordionItem(
                                project: project,
                                isExpanded: expandedProjectID == project.id,
                                isActive: workspaceHolder.isOpen(project.id),
                                branches: resolveBranches(for: project),
                                onToggle: { toggleExpand(project.id) },
                                onLaunch: { launchWorkspace(for: project) },
                                onOpenDashboard: { openDashboardForProject(project.id) }
                            )
                        }
                    }
                    .padding(DevtailTokens.Spacing.popoverPadding)
                }
                .scrollIndicators(.never)
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: DevtailTokens.Sizes.popoverMaxHeight)
                .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // ─── Footer ───
            HStack(spacing: DevtailTokens.Spacing.gapLarge) {
                Button { openDashboard() } label: {
                    Label("Manage…", systemImage: "square.grid.2x2")
                        .font(DevtailTokens.Typography.bodySmall)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
                .help("Open the Devtail dashboard")

                Spacer()

                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
                    .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal, DevtailTokens.Spacing.popoverPadding)
            .padding(.vertical, DevtailTokens.Spacing.gapMedium)
        }
        .frame(width: DevtailTokens.Sizes.popoverWidth)
        .background(popoverBackground)
        .task { store.loadProjects() }
        .onChange(of: store.projects) { _, _ in
            keyboardSelectedIndex = nil
        }
        .onChange(of: searchQuery) { _, _ in
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

    // MARK: - Background

    /// Same dark gradient used by the dashboard window. Keeps the popover
    /// visually consistent with the rest of the app instead of inheriting
    /// the translucent system material.
    private var popoverBackground: LinearGradient {
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

    // MARK: - Accordion

    private func toggleExpand(_ projectID: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedProjectID == projectID {
                expandedProjectID = nil
            } else {
                expandedProjectID = projectID
            }
        }
    }

    // MARK: - Launch

    private func launchWorkspace(for project: Project) {
        store.prepareLaunch(for: project)
        openWindow(id: WindowID.workspace, value: project.id)
    }

    // MARK: - Branch detection

    private func resolveBranches(for project: Project) -> [UUID: String] {
        guard !project.directoryPath.isEmpty else { return [:] }
        let root = URL(fileURLWithPath: project.directoryPath)
        var branches: [UUID: String] = [:]
        for pane in project.workspacePanes {
            let paneDir = root.appendingPathComponent(pane.relativeCwd)
            if let branch = branchDetector.detectBranch(in: paneDir) {
                branches[pane.id] = branch
            }
        }
        return branches
    }

    // MARK: - Keyboard navigation

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

    private func commitKeyboardSelection() -> KeyPress.Result {
        guard let index = keyboardSelectedIndex,
              filteredProjects.indices.contains(index) else {
            return .ignored
        }
        let project = filteredProjects[index]
        toggleExpand(project.id)
        return .handled
    }

    private func handleEscape() -> KeyPress.Result {
        if expandedProjectID != nil {
            expandedProjectID = nil
            return .handled
        }
        if !searchQuery.isEmpty {
            searchQuery = ""
            keyboardSelectedIndex = nil
            return .handled
        }
        keyboardSelectedIndex = nil
        return .ignored
    }

    // MARK: - Helpers

    private var filteredProjects: [Project] {
        filterEngine.filter(projects: store.projects, query: searchQuery)
    }

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
        .padding(DevtailTokens.Spacing.popoverPadding)
    }

    private var hasNoSearchResults: Bool {
        !store.projects.isEmpty
            && !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && filteredProjects.isEmpty
    }

    // MARK: - Navigation

    private func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: WindowID.dashboard)
    }

    private func openDashboardForCreate() {
        NSApp.activate(ignoringOtherApps: true)
        intentHolder.pending = .createProject
        openWindow(id: WindowID.dashboard)
    }

    private func openDashboardForProject(_ projectID: UUID) {
        NSApp.activate(ignoringOtherApps: true)
        intentHolder.pending = .showProject(projectID)
        openWindow(id: WindowID.dashboard)
    }
}
