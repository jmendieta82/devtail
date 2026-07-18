//
//  WorkspaceDashboardColumn.swift
//  Devtail
//
//  Right column of the workspace window: live project dashboard.
//  Read-only surface — all editing lives in ProjectFormView.
//

import SwiftUI

struct WorkspaceDashboardColumn: View {
    let session: WorkspaceSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapMedium) {
                headerCard
                processesSection
                branchSection
                quickLinksSection
                sessionSection
                claudeSection
            }
            .padding(DevtailTokens.Spacing.cardPadding)
        }
    }

    private var headerCard: some View {
        card {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    ActivityDot(isActive: !session.interactiveExited)
                    Text(session.projectName)
                        .font(.headline)
                    Spacer()
                }
                Text(session.root.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    /// Live status of every managed process — read-only mirror of the side
    /// panel's cards (lifecycle actions stay there).
    private var processesSection: some View {
        Group {
            if !session.supervisor.processes.isEmpty {
                card(title: "Processes") {
                    VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapMedium) {
                        ForEach(session.supervisor.processes) { process in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(process.state.displayColor)
                                    .frame(width: 6, height: 6)
                                Text(process.name)
                                    .font(DevtailTokens.Typography.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text(process.state.displayLabel)
                                    .font(DevtailTokens.Typography.captionSmall)
                                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var branchSection: some View {
        Group {
            if let branch = session.currentBranch {
                card(title: "Branch") {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
                            Label(branch, systemImage: "arrow.triangle.branch")
                                .font(DevtailTokens.Typography.caption)
                                .foregroundStyle(.secondary)
                            if let status = session.gitStatus {
                                gitStatusDetails(status)
                            }
                        }
                        Spacer()
                        Button {
                            session.refreshGitStatus()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.icon)
                        .foregroundStyle(.secondary)
                        .help("Refresh git status")
                    }
                }
            }
        }
    }

    /// Enriched git details shown once `gitStatus` has loaded: local branch
    /// count, dirty/clean state, and ahead/behind vs. upstream (hidden when
    /// there is no upstream configured).
    private func gitStatusDetails(_ status: GitStatus) -> some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
            Text("\(status.localBranches.count) branches")
                .font(DevtailTokens.Typography.captionSmall)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)

            Text(status.isDirty ? "\(status.changedFileCount) uncommitted" : "Clean")
                .font(DevtailTokens.Typography.captionSmall)
                .foregroundStyle(status.isDirty ? DevtailTokens.Colors.trafficYellow : DevtailTokens.Colors.trafficGreen)

            if let ahead = status.ahead, let behind = status.behind {
                Text("\u{2191}\(ahead) \u{2193}\(behind)")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
            }
        }
    }

    private var quickLinksSection: some View {
        card(title: "Quick Links") {
            QuickLinksPanel(projectID: session.projectId, isReadOnly: true, hideTitle: true)
        }
    }

    private var sessionSection: some View {
        card(title: "Session") {
            TimelineView(.periodic(from: session.openedAt, by: 1)) { context in
                Label(
                    WorkspaceSessionClock.elapsedLabel(from: session.openedAt, to: context.date),
                    systemImage: "clock"
                )
                .font(.callout.monospacedDigit())
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            }
        }
    }

    /// Claude Code project introspection: skill/agent/command/MCP server
    /// counts plus historical token usage, read from the project's and the
    /// user's `.claude/` configuration. Each category with items is
    /// expandable to list names. Shown even when the load hasn't completed
    /// yet or the project has no Claude config at all — "No Claude config"
    /// signals that clearly rather than hiding the card.
    private var claudeSection: some View {
        card {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapMedium) {
                HStack {
                    SectionHeader(title: "Claude")
                    Spacer()
                    Button {
                        session.refreshClaudeInfo()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.icon)
                    .foregroundStyle(.secondary)
                    .help("Refresh Claude info")
                }

                if let info = session.claudeInfo, !info.isEmpty {
                    claudeCategoryRow(title: "skills", items: info.skills, systemImage: "sparkles")
                    claudeCategoryRow(title: "agents", items: info.agents, systemImage: "person.crop.circle")
                    claudeCategoryRow(title: "commands", items: info.commands, systemImage: "slash.circle")
                    claudeMCPRow(info.mcpServers)
                    if let usage = info.tokenUsage {
                        Label("\(TokenCountFormatter.format(usage.total)) tokens", systemImage: "number")
                            .font(DevtailTokens.Typography.caption)
                            .foregroundStyle(DevtailTokens.Colors.textSecondary)
                    }
                } else {
                    Text("No Claude config")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textSecondary)
                }
            }
        }
    }

    /// One expandable row for a skills/agents/commands category. Collapsed
    /// to just the count when empty (no disclosure — nothing to expand
    /// into); expandable to the item list otherwise.
    private func claudeCategoryRow(title: String, items: [ClaudeItem], systemImage: String) -> some View {
        Group {
            if items.isEmpty {
                Label("0 \(title)", systemImage: systemImage)
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
            } else {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
                        ForEach(items, id: \.name) { item in
                            Text(item.scope == .global ? "\(item.name) \u{00B7} global" : item.name)
                                .font(DevtailTokens.Typography.captionSmall)
                                .foregroundStyle(DevtailTokens.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, DevtailTokens.Spacing.gapTiny)
                } label: {
                    Label("\(items.count) \(title)", systemImage: systemImage)
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textSecondary)
                }
            }
        }
    }

    /// MCP servers row: same expandable shape as `claudeCategoryRow`, but
    /// the source data is `[String]` (server names only, no per-item
    /// detail/scope) rather than `[ClaudeItem]`.
    private func claudeMCPRow(_ servers: [String]) -> some View {
        Group {
            if servers.isEmpty {
                Label("0 MCP servers", systemImage: "network")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
            } else {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
                        ForEach(servers, id: \.self) { server in
                            Text(server)
                                .font(DevtailTokens.Typography.captionSmall)
                                .foregroundStyle(DevtailTokens.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, DevtailTokens.Spacing.gapTiny)
                } label: {
                    Label("\(servers.count) MCP servers", systemImage: "network")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textSecondary)
                }
            }
        }
    }

    /// Dashboard card: the accent-tinted surface from QuickLinkChip scaled
    /// up to a section container (same fill/stroke recipe so the column
    /// reads as one family with the repository chips).
    private func card<Content: View>(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapMedium) {
            if let title {
                SectionHeader(title: title)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DevtailTokens.Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                .fill(DevtailTokens.Colors.accentPrimary.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                .stroke(DevtailTokens.Colors.accentPrimary.opacity(0.25),
                        lineWidth: DevtailTokens.BorderWidth.default)
        )
    }
}
