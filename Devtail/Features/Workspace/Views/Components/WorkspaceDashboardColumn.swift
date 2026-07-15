//
//  WorkspaceDashboardColumn.swift
//  Devtail
//
//  Left column of the workspace window: live project dashboard.
//  Read-only surface — all editing lives in ProjectFormView.
//

import SwiftUI

struct WorkspaceDashboardColumn: View {
    let session: WorkspaceSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
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

    private var processesSection: some View {
        Group {
            SectionHeader(title: "Processes")
            ForEach(session.supervisor.processes) { process in
                ProcessCardView(
                    process: process,
                    isSelected: session.selectedTab == .process(process.id),
                    onSelect: {
                        // Never-started processes have no session, hence no tab —
                        // selecting the card must not point at a tab that renders nothing.
                        if process.session != nil { session.selectedTab = .process(process.id) }
                    },
                    onStart: {
                        // Start opens the tab: after start() the session exists,
                        // so selecting immediately shows the live process view.
                        session.supervisor.start(process)
                        session.selectedTab = .process(process.id)
                    },
                    onStop: { session.supervisor.stop(process) },
                    onRestart: { session.supervisor.restart(process) }
                )
            }
        }
    }

    private var branchSection: some View {
        Group {
            if let branch = session.currentBranch {
                SectionHeader(title: "Branch")
                Label(branch, systemImage: "arrow.triangle.branch")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quickLinksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Quick Links")
            QuickLinksPanel(projectID: session.projectId, isReadOnly: true, hideTitle: true)
        }
    }

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Session")
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
}
