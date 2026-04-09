//
//  DetailPanel.swift
//  Devtail
//
//  Tabbed detail panel below the project list. Hosts two tabs:
//  Quick Links and Workspace. Tab selection resets to .quickLinks
//  when the selected project changes.
//

import SwiftUI
import SwiftData

enum DetailTab {
    case quickLinks
    case workspace
}

struct DetailPanel: View {
    let projectID: UUID?
    /// When true, the panel propagates read-only to its child panels
    /// AND surfaces an "Edit" affordance in the tab bar that the
    /// caller wires to open the dashboard for the selected project.
    /// The popover is the only call site today, but the parameter
    /// keeps the API honest if the dashboard ever wants to embed
    /// DetailPanel later.
    var isReadOnly: Bool = false
    /// Invoked when the user taps the Edit button surfaced in
    /// read-only mode. Receives the currently-selected project id —
    /// callers typically open the dashboard via `DashboardIntent
    /// .editProject(id)`. Ignored when `isReadOnly` is false.
    var onEditProject: ((UUID) -> Void)? = nil

    @Environment(ProjectStore.self) private var store
    /// Default tab is Workspace because Launch is the primary verb of
    /// the popover — opening Devtail and pressing Launch should be a
    /// two-click flow, not three. Quick Links are secondary affordances.
    @State private var selectedTab: DetailTab = .workspace

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            tabContent
        }
        .frame(height: DevtailTokens.Sizes.detailPanelHeight)
        .onChange(of: projectID) { _, _ in
            // Re-anchor on Workspace whenever the user switches projects
            // — same reasoning as the initial default.
            selectedTab = .workspace
        }
    }

    private var currentProject: Project? {
        guard let projectID else { return nil }
        return store.projects.first { $0.id == projectID }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            // WORKSPACE first — it hosts the Launch button, which is
            // the primary action of the entire popover.
            tabButton(title: "WORKSPACE", tab: .workspace)
            tabButton(title: "QUICK LINKS", tab: .quickLinks)
            Spacer()

            // Read-only callers (the menubar popover) get an inline
            // Edit affordance that hands off to the dashboard. We put
            // it on the right edge of the tab bar instead of building
            // a dedicated header so we don't steal vertical space —
            // the popover is tight and every row counts.
            if isReadOnly,
               let project = currentProject,
               let onEditProject {
                Button {
                    onEditProject(project.id)
                } label: {
                    HStack(spacing: DevtailTokens.Spacing.gapTiny) {
                        Image(systemName: "pencil")
                            .font(DevtailTokens.Typography.captionSmall)
                        Text("Edit")
                            .font(DevtailTokens.Typography.captionSmall)
                    }
                    .foregroundStyle(DevtailTokens.Colors.accentGreen)
                    .padding(.horizontal, DevtailTokens.Spacing.gapSmall)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .help("Edit \(project.name) in the dashboard")
            }
        }
        .padding(.horizontal, DevtailTokens.Spacing.popoverPadding)
        .padding(.top, DevtailTokens.Spacing.gapMedium)
        .padding(.bottom, DevtailTokens.Spacing.gapSmall)
    }

    @ViewBuilder
    private func tabButton(title: String, tab: DetailTab) -> some View {
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
                .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
                .padding(.vertical, DevtailTokens.Spacing.gapSmall)
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

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .quickLinks:
            QuickLinksPanel(projectID: projectID, isReadOnly: isReadOnly)
        case .workspace:
            WorkspacePanel(projectID: projectID, isReadOnly: isReadOnly)
        }
    }
}

#Preview {
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
        if let project = store.projects.first {
            store.addQuickLink(label: "GitHub", url: "https://github.com", to: project)
        }
        return store
    }()
    DetailPanel(projectID: store.projects.first?.id)
        .environment(store)
        .frame(width: 320)
        .background(DevtailTokens.Colors.popoverBackground)
}
