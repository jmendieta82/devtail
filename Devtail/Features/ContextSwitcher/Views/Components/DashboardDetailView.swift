import SwiftUI
import AppKit

/// Scrollable detail view for the dashboard.
/// Browsing mode shows a JetBrains-style welcome hero header; details mode
/// shows the read-only full project info (layout, panes, quick links, metadata).
struct DashboardDetailView: View {
    let project: Project
    let onDeleteProject: (Project) -> Void

    @Environment(ProjectStore.self) private var store
    @Environment(WorkspaceSessionsHolder.self) private var workspaceHolder
    @Environment(\.openWindow) private var openWindow

    @State private var showDeleteConfirmation: Bool = false
    @State private var isShowingDetails: Bool = false
    /// Branch changes detected when the user taps Resume. Non-empty triggers
    /// the confirmation alert before proceeding.
    @State private var pendingBranchChanges: [BranchChange] = []
    @State private var showResumeAlert: Bool = false

    private let branchDetector = GitBranchDetector()

    private var sortedPanes: [WorkspacePane] {
        project.workspacePanes.sorted { $0.order < $1.order }
    }

    @ViewBuilder
    var body: some View {
        if isShowingDetails {
            detailsMode
        } else {
            browsingMode
        }
    }

    @ViewBuilder
    private var browsingMode: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSection) {
                heroHeader
            }
            .padding(DevtailTokens.Spacing.dashboardPadding)
        }
    }

    // MARK: - Details Mode (read-only full project info)

    @ViewBuilder
    private var detailsMode: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSection) {
                detailsHeader

                detailsGeneralSection
                detailsLayoutSection
                detailsPanesSection
                detailsQuickLinksSection
                detailsTimestampsSection
            }
            .padding(DevtailTokens.Spacing.dashboardPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var detailsHeader: some View {
        HStack(spacing: DevtailTokens.Spacing.gapMedium) {
            Button {
                isShowingDetails = false
            } label: {
                HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(DevtailTokens.Typography.bodySmall)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
                .padding(.horizontal, DevtailTokens.Spacing.gapLarge)
                .padding(.vertical, DevtailTokens.Spacing.gapMedium)
                .contentShape(
                    RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                        .stroke(DevtailTokens.Colors.borderSubtle, lineWidth: DevtailTokens.BorderWidth.default)
                )
            }
            .buttonStyle(.plain)
            .help("Back to workspace")

            Spacer()

            VStack(alignment: .trailing, spacing: DevtailTokens.Spacing.gapTiny) {
                Text("Project details")
                    .font(DevtailTokens.Typography.projectTitle)
                    .foregroundStyle(DevtailTokens.Colors.textPrimary)
                Text(project.name)
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
            }
        }
    }

    @ViewBuilder
    private var detailsGeneralSection: some View {
        detailsSection(title: "GENERAL") {
            detailsRow(label: "Name", value: project.name)
            detailsRow(
                label: "Directory",
                value: project.directoryPath.isEmpty ? "—" : project.directoryPath,
                monospaced: true
            )
            if let notes = project.notes, !notes.isEmpty {
                detailsRow(label: "Notes", value: notes)
            }
        }
    }

    @ViewBuilder
    private var detailsLayoutSection: some View {
        detailsSection(title: "LAYOUT") {
            detailsRow(label: "Arrangement", value: project.layout.displayName)
            detailsRow(label: "Slots", value: "\(project.layout.slotCount)")
            detailsRow(label: "Panes configured", value: "\(sortedPanes.count)")
        }
    }

    @ViewBuilder
    private var detailsPanesSection: some View {
        detailsSection(title: "PANES") {
            if sortedPanes.isEmpty {
                Text("No panes configured.")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
            } else {
                VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapLarge) {
                    ForEach(sortedPanes, id: \.id) { pane in
                        paneDetailBlock(for: pane)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func paneDetailBlock(for pane: WorkspacePane) -> some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
            HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                Text(pane.label)
                    .font(DevtailTokens.Typography.bodySemibold)
                    .foregroundStyle(DevtailTokens.Colors.textPrimary)
                if pane.layoutSlot >= 0 {
                    Text("Slot \(pane.layoutSlot + 1)")
                        .font(DevtailTokens.Typography.captionSmall)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                }
                if let env = pane.environment {
                    EnvironmentPill(environment: env, compact: true)
                }
            }
            detailsRow(
                label: "Relative cwd",
                value: pane.relativeCwd.isEmpty ? "—" : pane.relativeCwd,
                monospaced: true
            )
            detailsRow(
                label: "Command",
                value: pane.command.isEmpty ? "—" : pane.command,
                monospaced: true
            )
            if let stack = pane.stack, !stack.isEmpty {
                detailsRow(label: "Stack", value: stack)
            }
            // Same guard as MenuBarRootView.resolveBranches: an empty
            // directoryPath would build a relative URL and the detector
            // rejects those — skip the row instead of probing garbage.
            if !project.directoryPath.isEmpty,
               let branch = branchDetector.detectBranch(
                in: URL(fileURLWithPath: project.directoryPath)
                    .appendingPathComponent(pane.relativeCwd)
               ) {
                detailsRow(label: "Current branch", value: branch)
            }
        }
        .padding(DevtailTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                .fill(DevtailTokens.Colors.accentPrimary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                .stroke(
                    DevtailTokens.Colors.accentPrimary.opacity(0.20),
                    lineWidth: DevtailTokens.BorderWidth.default
                )
        )
    }

    @ViewBuilder
    private var detailsQuickLinksSection: some View {
        detailsSection(title: "QUICK LINKS") {
            let links = project.quickLinks.sorted { $0.order < $1.order }
            if links.isEmpty {
                Text("No quick links yet.")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
            } else {
                VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapMedium) {
                    ForEach(links, id: \.id) { link in
                        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
                            Text(link.label)
                                .font(DevtailTokens.Typography.bodyDefault)
                                .foregroundStyle(DevtailTokens.Colors.textPrimary)
                            Text(link.url)
                                .font(DevtailTokens.Typography.mono)
                                .foregroundStyle(DevtailTokens.Colors.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailsTimestampsSection: some View {
        detailsSection(title: "METADATA") {
            detailsRow(label: "Created", value: formatDate(project.createdAt))
            detailsRow(label: "Updated", value: formatDate(project.updatedAt))
        }
    }

    @ViewBuilder
    private func detailsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapMedium) {
            Text(title)
                .font(DevtailTokens.Typography.captionSmall)
                .tracking(0.5)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
            content()
        }
    }

    @ViewBuilder
    private func detailsRow(label: String, value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .top, spacing: DevtailTokens.Spacing.gapLarge) {
            Text(label)
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(
                    monospaced
                        ? DevtailTokens.Typography.mono
                        : DevtailTokens.Typography.bodySmall
                )
                .foregroundStyle(DevtailTokens.Colors.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Section A: Hero Header

    @ViewBuilder
    private var heroHeader: some View {
        HStack(alignment: .center, spacing: DevtailTokens.Spacing.gapLarge) {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
                HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                    ActivityDot(isActive: workspaceHolder.isOpen(project.id))

                    Text(project.name)
                        .font(DevtailTokens.Typography.projectTitle)
                        .foregroundStyle(DevtailTokens.Colors.textPrimary)
                        .lineLimit(1)

                    Text("·")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)

                    Text("\(project.layout.displayName) · \(sortedPanes.count) pane\(sortedPanes.count == 1 ? "" : "s")")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                        .lineLimit(1)
                }

                if !project.directoryPath.isEmpty {
                    HStack(spacing: DevtailTokens.Spacing.gapTiny) {
                        Image(systemName: "folder")
                            .font(DevtailTokens.Typography.captionSmall)
                            .foregroundStyle(DevtailTokens.Colors.textTertiary)
                        Text(project.directoryPath)
                            .font(DevtailTokens.Typography.mono)
                            .foregroundStyle(DevtailTokens.Colors.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            Spacer()

            HStack(spacing: DevtailTokens.Spacing.gapMedium) {
                // Project actions menu (Details / Delete)
                Menu {
                    Button {
                        isShowingDetails = true
                    } label: {
                        Label("View details", systemImage: "info.circle")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete project", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(DevtailTokens.Typography.bodyDefault)
                        .foregroundStyle(DevtailTokens.Colors.textSecondary)
                        .frame(
                            width: DevtailTokens.Sizes.launchButtonHeight,
                            height: DevtailTokens.Sizes.launchButtonHeight
                        )
                        .contentShape(
                            RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                                .stroke(
                                    DevtailTokens.Colors.borderSubtle,
                                    lineWidth: DevtailTokens.BorderWidth.default
                                )
                        }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Project actions")

                // Launch editor (VSCode)
                Button {
                    store.openInVSCode(project: project)
                } label: {
                    vscodeIcon
                        .frame(
                            width: DevtailTokens.Sizes.launchButtonHeight,
                            height: DevtailTokens.Sizes.launchButtonHeight
                        )
                        .contentShape(
                            RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                                .stroke(
                                    DevtailTokens.Colors.borderSubtle,
                                    lineWidth: DevtailTokens.BorderWidth.default
                                )
                        }
                }
                .buttonStyle(.plain)
                .disabled(project.directoryPath.isEmpty)
                .help("Launch editor")

                // Resume (secondary — only when project has been launched before)
                if project.lastLaunchedAt != nil {
                    resumeButton
                }

                // Launch (primary)
                Button {
                    launchWorkspace()
                } label: {
                    HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                        Image(systemName: "play.fill")
                        Text("Launch")
                    }
                    .font(DevtailTokens.Typography.bodySemibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DevtailTokens.Spacing.gapXLarge)
                    .frame(height: DevtailTokens.Sizes.launchButtonHeight)
                    .contentShape(
                        RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                            .fill(DevtailTokens.Colors.accentPrimary)
                    )
                }
                .buttonStyle(.plain)
                .disabled(sortedPanes.isEmpty || project.directoryPath.isEmpty)
                .help("Launch workspace")
            }
        }
        .confirmationDialog(
            "Delete \(project.name)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete project", role: .destructive) {
                onDeleteProject(project)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete the project and all its workspace panes and quick links. This cannot be undone.")
        }
        .alert(
            "Continue where you left off?",
            isPresented: $showResumeAlert
        ) {
            Button("Resume") {
                launchWorkspace()
            }
            Button("Cancel", role: .cancel) {
                pendingBranchChanges = []
            }
        } message: {
            Text(resumeAlertMessage)
        }
    }

    @ViewBuilder
    private var resumeButton: some View {
        Button {
            handleResumeTap()
        } label: {
            HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                Image(systemName: "arrow.uturn.forward")
                Text("Resume")
            }
            .font(DevtailTokens.Typography.bodySmall)
            .foregroundStyle(DevtailTokens.Colors.accentPrimary.opacity(0.85))
            .padding(.horizontal, DevtailTokens.Spacing.gapLarge)
            .frame(height: DevtailTokens.Sizes.launchButtonHeight)
            .contentShape(
                RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                    .stroke(
                        DevtailTokens.Colors.accentPrimary.opacity(0.35),
                        lineWidth: DevtailTokens.BorderWidth.default
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(sortedPanes.isEmpty || project.directoryPath.isEmpty)
        .help("Resume last session")
    }

    private var resumeAlertMessage: String {
        guard !pendingBranchChanges.isEmpty else { return "" }
        let lines = pendingBranchChanges.map { "• \($0.paneLabel): \($0.from) → \($0.to)" }
        return "Branches changed since your last session:\n" + lines.joined(separator: "\n")
    }

    private func handleResumeTap() {
        let changes = store.detectBranchChanges(for: project)
        if changes.isEmpty {
            launchWorkspace()
        } else {
            pendingBranchChanges = changes
            showResumeAlert = true
        }
    }

    // MARK: - Helpers

    /// Real VSCode icon pulled from the installed .app bundle via
    /// LaunchServices. Falls back to a generic SF Symbol when VSCode
    /// isn't installed so the button still renders.
    @ViewBuilder
    private var vscodeIcon: some View {
        if let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.microsoft.VSCode"
        ) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(DevtailTokens.Spacing.gapTiny)
        } else {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(DevtailTokens.Typography.bodyDefault)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
        }
    }

    private func launchWorkspace() {
        store.prepareLaunch(for: project)
        openWindow(id: WindowID.workspace, value: project.id)
    }
}
