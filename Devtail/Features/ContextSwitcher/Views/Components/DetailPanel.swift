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

    @State private var selectedTab: DetailTab = .quickLinks

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            tabContent
        }
        .frame(height: DevtailTokens.Sizes.detailPanelHeight)
        .onChange(of: projectID) { _, _ in
            selectedTab = .quickLinks
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "QUICK LINKS", tab: .quickLinks)
            tabButton(title: "WORKSPACE", tab: .workspace)
            Spacer()
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
            QuickLinksPanel(projectID: projectID)
        case .workspace:
            WorkspacePanel(projectID: projectID)
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
        store.createProject(name: "Devtail", color: .green, environment: .dev)
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
