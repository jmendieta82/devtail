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
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(.secondary)
                }
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
            TimelineView(.periodic(from: session.openedAt, by: 60)) { context in
                Label(
                    WorkspaceSessionClock.elapsedLabel(from: session.openedAt, to: context.date),
                    systemImage: "clock"
                )
                .font(.callout)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
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
