//
//  WorkspaceRootView.swift
//  Devtail
//
//  The per-project work window: interactive terminal as the hero, a tab row
//  to flip between terminal and process logs, and a slim sidebar of process
//  cards. CRITICAL: terminal views are all mounted in a ZStack and merely
//  hidden — removing one from the hierarchy would destroy scrollback.
//

import SwiftUI

struct WorkspaceRootView: View {
    @Environment(WorkspaceSessionsHolder.self) private var holder
    let session: WorkspaceSession

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                tabRow
                terminalArea
            }
            .frame(minWidth: 640, maxWidth: .infinity, maxHeight: .infinity)

            sidebar
                .frame(minWidth: 220, maxWidth: 300)
        }
        .navigationTitle(session.projectName)
        .onDisappear { holder.close(projectId: session.projectId) }
    }

    private var tabRow: some View {
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            tabButton(title: "terminal", id: nil)
            ForEach(session.supervisor.processes) { process in
                tabButton(title: process.name, id: process.id)
            }
            Spacer()
        }
        .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
    }

    private func tabButton(title: String, id: UUID?) -> some View {
        Button(title) { session.selectedTab = id }
            .buttonStyle(.plain)
            .font(DevtailTokens.Typography.caption)
            .foregroundStyle(session.selectedTab == id ? .primary : .secondary)
    }

    /// All terminal views stay mounted; opacity flips visibility. allowsHitTesting
    /// keeps hidden terminals from swallowing clicks.
    private var terminalArea: some View {
        ZStack {
            TerminalHostView(terminalView: session.interactive.view)
                .opacity(session.selectedTab == nil ? 1 : 0)
                .allowsHitTesting(session.selectedTab == nil)
            ForEach(session.supervisor.processes) { process in
                if let view = process.session?.view {
                    TerminalHostView(terminalView: view)
                        .opacity(session.selectedTab == process.id ? 1 : 0)
                        .allowsHitTesting(session.selectedTab == process.id)
                }
            }
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
                SectionHeader(title: "Processes")
                ForEach(session.supervisor.processes) { process in
                    ProcessCardView(
                        process: process,
                        isSelected: session.selectedTab == process.id,
                        onSelect: { session.selectedTab = process.id },
                        onStart: { session.supervisor.start(process) },
                        onStop: { session.supervisor.stop(process) },
                        onRestart: { session.supervisor.restart(process) }
                    )
                }

                if let branch = session.currentBranch {
                    SectionHeader(title: "Branch")
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                if !session.quickLinks.isEmpty {
                    SectionHeader(title: "Quick Links")
                    ForEach(session.quickLinks, id: \.url) { link in
                        Link(link.title, destination: URL(string: link.url) ?? URL(fileURLWithPath: "/"))
                            .font(DevtailTokens.Typography.caption)
                    }
                }
            }
            .padding(DevtailTokens.Spacing.cardPadding)
        }
    }
}
