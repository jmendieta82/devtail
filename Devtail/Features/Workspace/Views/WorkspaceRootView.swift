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

            FileTreeColumn(session: session)
                .frame(minWidth: 220, maxWidth: 300)
        }
        .navigationTitle(session.projectName)
        .onDisappear { holder.close(projectId: session.projectId) }
    }

    private var tabRow: some View {
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            terminalTab
            tabButton(title: "agent", tab: .agent)
            ForEach(session.supervisor.processes) { process in
                // On-demand tab: only processes with a live session (running,
                // or exited/stopped with scrollback preserved) get a tab.
                if process.session != nil {
                    processTab(for: process)
                }
            }
            ForEach(session.openFiles) { file in
                fileTab(for: file)
            }
            Spacer()
        }
        .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
    }

    /// Terminal tab is both the opener (click spawns the interactive shell if
    /// not already live) and, once live, closable — closing kills the PTY.
    private var terminalTab: some View {
        HStack(spacing: 4) {
            Button("terminal") {
                holder.openInteractive(projectId: session.projectId)
                session.selectedTab = .terminal
            }
            .buttonStyle(.plain)
            .font(DevtailTokens.Typography.caption)
            .foregroundStyle(session.selectedTab == .terminal ? .primary : .secondary)

            if session.interactive != nil {
                Button {
                    holder.closeInteractive(projectId: session.projectId)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tabButton(title: String, tab: WorkspaceTab) -> some View {
        Button(title) { session.selectedTab = tab }
            .buttonStyle(.plain)
            .font(DevtailTokens.Typography.caption)
            .foregroundStyle(session.selectedTab == tab ? .primary : .secondary)
    }

    private func processTab(for process: ManagedProcess) -> some View {
        HStack(spacing: 4) {
            Button(process.name) { session.selectedTab = .process(process.id) }
                .buttonStyle(.plain)
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(session.selectedTab == .process(process.id) ? .primary : .secondary)
            Button {
                if session.selectedTab == .process(process.id) { session.selectedTab = .agent }
                session.supervisor.close(process)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func fileTab(for file: OpenFile) -> some View {
        HStack(spacing: 4) {
            Button(file.name) { session.selectedTab = .file(file.path) }
                .buttonStyle(.plain)
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(session.selectedTab == .file(file.path) ? .primary : .secondary)
            Button {
                session.closeFile(at: file.path)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    /// Terminal views stay mounted while alive; opacity flips visibility.
    /// allowsHitTesting keeps hidden terminals from swallowing clicks. The
    /// interactive terminal is mounted conditionally (unlike the agent,
    /// which is always mounted) — closing it kills the PTY, so there's
    /// nothing to preserve; while it's alive it stays mounted regardless of
    /// selection, preserving scrollback across tab switches.
    private var terminalArea: some View {
        ZStack {
            if let interactive = session.interactive {
                TerminalHostView(terminalView: interactive.view, isActive: session.selectedTab == .terminal)
                    .opacity(session.selectedTab == .terminal ? 1 : 0)
                    .allowsHitTesting(session.selectedTab == .terminal)
            }
            TerminalHostView(terminalView: session.agent.view, isActive: session.selectedTab == .agent)
                .opacity(session.selectedTab == .agent ? 1 : 0)
                .allowsHitTesting(session.selectedTab == .agent)
            ForEach(session.supervisor.processes) { process in
                if let view = process.session?.view {
                    TerminalHostView(terminalView: view, isActive: session.selectedTab == .process(process.id))
                        .opacity(session.selectedTab == .process(process.id) ? 1 : 0)
                        .allowsHitTesting(session.selectedTab == .process(process.id))
                }
            }

            // File viewer tab: mounted conditionally (no PTY to preserve, unlike
            // the terminal views above which stay mounted always).
            if case .file(let path) = session.selectedTab {
                FileViewerTabView(path: path)
            }

            // Dead-state affordance: the exited terminal view stays mounted
            // underneath (scrollback stays readable) — this just floats a
            // restart prompt over it. User-initiated only, no auto-respawn.
            if session.selectedTab == .terminal && session.interactiveExited {
                deadShellOverlay
            }
            if session.selectedTab == .agent && session.agentExited {
                deadAgentOverlay
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

    private var deadAgentOverlay: some View {
        VStack(spacing: DevtailTokens.Spacing.gapMedium) {
            Text("agent exited")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Button("Restart agent") {
                holder.restartAgent(projectId: session.projectId)
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
