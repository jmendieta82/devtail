//
//  WorkspaceRootView.swift
//  Devtail
//
//  The per-project work window: interactive terminal as the hero, a tab row
//  to flip between terminal and process logs, and a project dashboard column.
//  CRITICAL: terminal views are all mounted in a ZStack and merely hidden —
//  removing one from the hierarchy would destroy scrollback.
//

import SwiftUI

struct WorkspaceRootView: View {
    @Environment(WorkspaceSessionsHolder.self) private var holder
    let session: WorkspaceSession

    var body: some View {
        HSplitView {
            WorkspaceDashboardColumn(session: session)
                .frame(minWidth: 260, maxWidth: 340)

            VStack(spacing: 0) {
                tabRow
                terminalArea
            }
            .frame(minWidth: 640, maxWidth: .infinity, maxHeight: .infinity)

            FileTreePlaceholderColumn()
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

            // Dead-state affordance: the exited terminal view stays mounted
            // underneath (scrollback stays readable) — this just floats a
            // restart prompt over it. User-initiated only, no auto-respawn.
            if session.selectedTab == nil && session.interactiveExited {
                deadShellOverlay
            }
        }
    }

    private var deadShellOverlay: some View {
        VStack(spacing: DevtailTokens.Spacing.gapMedium) {
            Text("shell exited")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Button("Restart shell") {
                holder.restartInteractive(projectId: session.projectId)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(DevtailTokens.Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                .fill(DevtailTokens.Colors.popoverBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                .stroke(DevtailTokens.Colors.borderSubtle, lineWidth: DevtailTokens.BorderWidth.default)
        )
    }
}
