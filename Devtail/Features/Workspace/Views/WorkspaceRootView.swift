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
    @Environment(AppSettings.self) private var settings
    let session: WorkspaceSession

    /// Set when a dirty env file tab's close button is clicked — drives the
    /// close-confirmation dialog below. Nil the rest of the time.
    @State private var pendingCloseFilePath: String?

    var body: some View {
        // The font-size re-identification wraps ONLY the split content: the
        // outer Group keeps a stable identity so the onDisappear teardown
        // below never fires on a text-size change — session, terminals and
        // file tree survive the rebuild (their state lives in the session).
        Group {
            splitContent
                .id(settings.uiFontSize)
        }
        .navigationTitle(session.projectName)
        .background(
            // Hidden Cmd+P registration: from anywhere in the workspace
            // window, switch the side panel to Files and focus the file
            // search field (FileTreeColumn consumes the request).
            Button("") {
                session.sidePanel = .files
                session.fileSearch.requestFocus()
            }
            .keyboardShortcut("p", modifiers: .command)
            .hidden()
        )
        .onDisappear { holder.close(projectId: session.projectId) }
        .confirmationDialog(
            "Save changes before closing?",
            isPresented: Binding(
                get: { pendingCloseFilePath != nil },
                set: { if !$0 { pendingCloseFilePath = nil } }
            ),
            presenting: pendingCloseFilePath
        ) { path in
            Button("Save and close") {
                session.saveAndCloseFile(at: path)
                pendingCloseFilePath = nil
            }
            Button("Discard", role: .destructive) {
                session.closeFile(at: path)
                pendingCloseFilePath = nil
            }
            Button("Cancel", role: .cancel) {
                pendingCloseFilePath = nil
            }
        }
    }

    private var splitContent: some View {
        HSplitView {
            HStack(spacing: 0) {
                ActivityBar(session: session)
                    .background(DevtailTokens.Colors.titleBar)
                if session.sidePanel != nil {
                    // separatorColor is a hairline that vanishes between two
                    // identical dark fills — use an explicit primary tint so
                    // the rail/panel boundary stays visible in both
                    // appearances.
                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: DevtailTokens.BorderWidth.default)
                    WorkspaceSidePanel(session: session)
                }
            }
            // idealWidth pinned to maxWidth: HSplitView opens children at
            // their ideal size, so without it both panels debut at their
            // minimum and look cramped until manually dragged.
            .frame(
                minWidth: session.sidePanel == nil ? 48 : 48 + 1 + 220,
                idealWidth: session.sidePanel == nil ? 48 : 48 + 1 + 300,
                maxWidth: session.sidePanel == nil ? 48 : 48 + 1 + 300
            )

            VStack(spacing: 0) {
                tabRow
                terminalArea
            }
            .frame(minWidth: 640, maxWidth: .infinity, maxHeight: .infinity)

            if session.dashboardCollapsed {
                collapsedDashboardStrip
            } else {
                WorkspaceDashboardColumn(session: session)
                    .frame(minWidth: 260, idealWidth: 340, maxWidth: 340)
            }
        }
    }

    /// Slim strip shown in place of `WorkspaceDashboardColumn` when
    /// `dashboardCollapsed` is true. Uses the Xcode-style trailing-sidebar
    /// toggle glyph so show/hide reads as the standard macOS panel
    /// control, mirrored by the collapse button in the expanded column.
    private var collapsedDashboardStrip: some View {
        VStack {
            Button {
                session.dashboardCollapsed = false
            } label: {
                Image(systemName: "sidebar.trailing")
                    .font(.system(size: 18))
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.icon)
            .help("Show project panel")
            .padding(.top, DevtailTokens.Spacing.gapSmall)

            Spacer()
        }
        .frame(width: 44)
        .background(DevtailTokens.Colors.titleBar)
    }

    private var tabRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                terminalTab
                WorkspaceTabChip(
                    icon: "sparkles",
                    title: "agent",
                    isSelected: session.selectedTab == .agent,
                    select: { session.selectedTab = .agent },
                    close: nil
                )
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
                if session.selectedTab == .tasks {
                    WorkspaceTabChip(
                        icon: "checklist",
                        title: "tasks",
                        isSelected: true,
                        select: {},
                        close: { session.selectedTab = .agent }
                    )
                }
                if session.selectedTab == .settings {
                    WorkspaceTabChip(
                        icon: "gearshape",
                        title: "settings",
                        isSelected: true,
                        select: {},
                        close: { session.selectedTab = .agent }
                    )
                }
            }
            .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
            .padding(.vertical, DevtailTokens.Spacing.gapSmall)
        }
        .background(DevtailTokens.Colors.titleBar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DevtailTokens.Colors.borderSubtle)
                .frame(height: DevtailTokens.BorderWidth.default)
        }
    }

    /// Terminal tab is both the opener (click spawns the interactive shell if
    /// not already live) and, once live, closable — closing kills the PTY.
    private var terminalTab: some View {
        WorkspaceTabChip(
            icon: "terminal",
            title: "terminal",
            isSelected: session.selectedTab == .terminal,
            select: {
                holder.openInteractive(projectId: session.projectId)
                session.selectedTab = .terminal
            },
            close: session.interactive == nil ? nil : {
                holder.closeInteractive(projectId: session.projectId)
            }
        )
    }

    private func processTab(for process: ManagedProcess) -> some View {
        WorkspaceTabChip(
            icon: "gearshape",
            title: process.name,
            isSelected: session.selectedTab == .process(process.id),
            select: { session.selectedTab = .process(process.id) },
            close: {
                if session.selectedTab == .process(process.id) { session.selectedTab = .agent }
                session.supervisor.close(process)
            }
        )
    }

    private func fileTab(for file: OpenFile) -> some View {
        WorkspaceTabChip(
            icon: "doc.text",
            title: file.name,
            isSelected: session.selectedTab == .file(file.path),
            select: { session.selectedTab = .file(file.path) },
            close: { requestCloseFile(at: file.path) },
            isDirty: session.isDirty(path: file.path)
        )
    }

    /// Closing a dirty env file tab needs confirmation first (Save and
    /// close / Discard / Cancel) — everything else closes immediately, same
    /// as before this feature existed.
    private func requestCloseFile(at path: String) {
        guard session.isDirty(path: path) else {
            session.closeFile(at: path)
            return
        }
        pendingCloseFilePath = path
    }

    /// Terminal views stay mounted while alive; opacity flips visibility.
    /// allowsHitTesting keeps hidden terminals from swallowing clicks. The
    /// interactive terminal is mounted conditionally (unlike the agent,
    /// which is always mounted) — closing it kills the PTY, so there's
    /// nothing to preserve; while it's alive it stays mounted regardless of
    /// selection, preserving scrollback across tab switches.
    ///
    /// Padded and backed by the active theme's background color so the
    /// frame reads as one surface with the terminal itself — overlays (file
    /// viewer, settings tab, dead-state prompts) render inside this same
    /// frame, per spec.
    ///
    /// `appearance` is constructed here, inside this tracked SwiftUI body
    /// context — that read touches all 7 `AppSettings` terminal fields, so
    /// Observation registers a dependency on every one of them. Any field
    /// change re-renders this body, rebuilds `appearance` with a new token,
    /// and reconstructs every `TerminalHostView` below with it — which is
    /// what makes `updateNSView`'s token guard actually re-fire. See
    /// `TerminalHostView` for why it can't read settings itself.
    private var terminalArea: some View {
        let appearance = TerminalAppearance(settings: settings)
        return terminalStack(appearance: appearance)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(themeBackgroundColor)
    }

    private var themeBackgroundColor: Color {
        let background = TerminalTheme.theme(id: settings.terminalThemeId).background
        return Color(
            red: Double(background.red) / 255,
            green: Double(background.green) / 255,
            blue: Double(background.blue) / 255
        )
    }

    private func terminalStack(appearance: TerminalAppearance) -> some View {
        ZStack {
            if let interactive = session.interactive {
                TerminalHostView(terminalView: interactive.view, appearance: appearance, isActive: session.selectedTab == .terminal)
                    .opacity(session.selectedTab == .terminal ? 1 : 0)
                    .allowsHitTesting(session.selectedTab == .terminal)
            }
            TerminalHostView(terminalView: session.agent.view, appearance: appearance, isActive: session.selectedTab == .agent)
                .opacity(session.selectedTab == .agent ? 1 : 0)
                .allowsHitTesting(session.selectedTab == .agent)
            ForEach(session.supervisor.processes) { process in
                if let view = process.session?.view {
                    TerminalHostView(terminalView: view, appearance: appearance, isActive: session.selectedTab == .process(process.id))
                        .opacity(session.selectedTab == .process(process.id) ? 1 : 0)
                        .allowsHitTesting(session.selectedTab == .process(process.id))
                }
            }

            // File viewer tab: mounted conditionally (no PTY to preserve, unlike
            // the terminal views above which stay mounted always).
            if case .file(let path) = session.selectedTab {
                FileViewerTabView(path: path, session: session)
            }

            // Settings tab: mounted conditionally (no PTY to preserve), mirrors
            // the file viewer above.
            if session.selectedTab == .settings {
                WorkspaceSettingsTabView(session: session)
            }

            // Task board tab: mounted conditionally, no PTY to preserve.
            if session.selectedTab == .tasks {
                TaskBoardTabView(session: session)
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

/// One tab in the workspace tab row: icon + title, selected/hover backgrounds,
/// and an optional close button. Long titles are middle-truncated in code —
/// `.frame(maxWidth:)` on Text balloons the chip inside a horizontal ScrollView,
/// so layout-based truncation is not an option here.
struct WorkspaceTabChip: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let select: () -> Void
    let close: (() -> Void)?
    /// Shows a small dot before the title when true — the unsaved-changes
    /// indicator for a dirty env file tab. Defaults to false so every other
    /// caller (terminal, agent, process tabs) is unaffected. A separate
    /// glyph rather than a title prefix: keeps `truncated()` pure and out of
    /// the business of accounting for a marker in its character budget.
    var isDirty: Bool = false

    @State private var isHovering = false

    private static let maxTitleLength = 28

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            Button(action: select) {
                HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                    Image(systemName: icon)
                        .font(.system(size: 9))
                    if isDirty {
                        Circle()
                            .fill(DevtailTokens.Colors.accentPrimary)
                            .frame(width: 6, height: 6)
                    }
                    Text(Self.truncated(title))
                        .font(DevtailTokens.Typography.caption)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.icon)
            // Full name on hover — the tab label is middle-truncated at 28 chars.
            .help(title)

            if let close {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.icon)
                .foregroundStyle(.secondary)
                .help("Close")
            }
        }
        .foregroundStyle(isSelected ? DevtailTokens.Colors.textPrimary : DevtailTokens.Colors.textSecondary)
        .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
        .background(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.chip)
                .fill(isSelected ? DevtailTokens.Colors.activeRow : (isHovering ? DevtailTokens.Colors.hoverState.opacity(0.5) : .clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.chip)
                .stroke(isSelected ? DevtailTokens.Colors.borderSubtle : .clear, lineWidth: DevtailTokens.BorderWidth.default)
        )
        .onHover { isHovering = $0 }
    }

    /// Middle truncation keeps both the name's start and its extension visible
    /// (file tabs are often long dated names like `2026-06-22-frontend-….md`).
    static func truncated(_ title: String) -> String {
        guard title.count > maxTitleLength else { return title }
        let head = title.prefix(14)
        let tail = title.suffix(13)
        return "\(head)…\(tail)"
    }
}
