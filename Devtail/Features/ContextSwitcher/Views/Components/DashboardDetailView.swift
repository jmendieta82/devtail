import SwiftUI

/// Scrollable detail view for the dashboard.
/// Contains hero header, layout section, panes section, and quick links.
struct DashboardDetailView: View {
    let project: Project
    @Environment(ProjectStore.self) private var store
    @Environment(WorkspaceActivityMonitor.self) private var activityMonitor

    @State private var editingPaneID: UUID? = nil
    @State private var isAddingPane: Bool = false

    private let branchDetector = GitBranchDetector()

    private var sortedPanes: [WorkspacePane] {
        project.workspacePanes.sorted { $0.order < $1.order }
    }

    var body: some View {
        if let editingPane = sortedPanes.first(where: { $0.id == editingPaneID }) {
            paneEditMode(for: editingPane)
        } else if isAddingPane {
            paneAddMode
        } else {
            browsingMode
        }
    }

    @ViewBuilder
    private var browsingMode: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSection) {
                heroHeader
                layoutSection
                panesSection
                quickLinksSection
            }
            .padding(DevtailTokens.Spacing.dashboardPadding)
        }
    }

    // MARK: - Pane Edit Mode (full-screen form)

    @ViewBuilder
    private func paneEditMode(for pane: WorkspacePane) -> some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSection) {
            paneEditHeader(title: "Edit pane", subtitle: pane.label)

            WorkspacePaneEditRow(
                projectRoot: project.directoryPath,
                initialLabel: pane.label,
                initialRelativeCwd: pane.relativeCwd,
                initialCommand: pane.command,
                initialStack: pane.stack,
                initialEnvironment: pane.environment,
                onSave: { label, cwd, command, stack, env in
                    store.updateWorkspacePane(
                        pane,
                        label: label,
                        relativeCwd: cwd,
                        command: command,
                        stack: stack,
                        environment: env
                    )
                    editingPaneID = nil
                },
                onCancel: { editingPaneID = nil }
            )

            Spacer(minLength: 0)
        }
        .padding(DevtailTokens.Spacing.dashboardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var paneAddMode: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSection) {
            paneEditHeader(title: "New pane", subtitle: project.name)

            WorkspacePaneEditRow(
                projectRoot: project.directoryPath,
                onSave: { label, cwd, command, stack, env in
                    store.addWorkspacePane(
                        label: label,
                        relativeCwd: cwd,
                        command: command,
                        stack: stack,
                        environment: env,
                        to: project
                    )
                    isAddingPane = false
                },
                onCancel: { isAddingPane = false }
            )

            Spacer(minLength: 0)
        }
        .padding(DevtailTokens.Spacing.dashboardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func paneEditHeader(title: String, subtitle: String) -> some View {
        HStack(spacing: DevtailTokens.Spacing.gapMedium) {
            Button {
                editingPaneID = nil
                isAddingPane = false
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
                Text(title)
                    .font(DevtailTokens.Typography.projectTitle)
                    .foregroundStyle(DevtailTokens.Colors.textPrimary)
                Text(subtitle)
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
            }
        }
    }

    // MARK: - Section A: Hero Header

    @ViewBuilder
    private var heroHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
                HStack(spacing: DevtailTokens.Spacing.gapMedium) {
                    ColorDot(
                        color: project.color,
                        size: DevtailTokens.Sizes.projectDotLarge
                    )
                    .overlay(alignment: .bottomTrailing) {
                        ActivityDot(isActive: activityMonitor.isActive(projectID: project.id))
                    }

                    Text(project.name)
                        .font(DevtailTokens.Typography.projectTitle)
                        .foregroundStyle(DevtailTokens.Colors.textPrimary)
                }

                if !project.directoryPath.isEmpty {
                    Text(project.directoryPath)
                        .font(DevtailTokens.Typography.mono)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if activityMonitor.isActive(projectID: project.id) {
                    Text("Active")
                        .font(DevtailTokens.Typography.captionSmall)
                        .foregroundStyle(DevtailTokens.Colors.accentGreen)
                        .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
                        .padding(.vertical, DevtailTokens.Spacing.gapTiny)
                        .background(
                            DevtailTokens.Colors.accentGreen.opacity(
                                DevtailTokens.ActiveState.badgeBgOpacity
                            )
                        )
                        .clipShape(Capsule())
                }
            }

            Spacer()

            Button {
                launchWorkspace()
            } label: {
                HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                    Image(systemName: store.isLaunchingWorkspace ? "hourglass" : "play.fill")
                    Text(store.isLaunchingWorkspace ? "Launching..." : "Launch")
                }
                .font(DevtailTokens.Typography.bodySemibold)
                .foregroundStyle(.white)
                .padding(.horizontal, DevtailTokens.Spacing.gapXLarge)
                .frame(height: DevtailTokens.Sizes.launchButtonHeight)
                .background(
                    RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                        .fill(DevtailTokens.Colors.accentGreen)
                )
            }
            .buttonStyle(.plain)
            .disabled(store.isLaunchingWorkspace || sortedPanes.isEmpty || project.directoryPath.isEmpty)
            .help("Launch workspace in Ghostty")
        }
    }

    // MARK: - Section B: Layout

    @ViewBuilder
    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapLarge) {
            SectionHeader(
                title: "LAYOUT",
                guide: "Choose how your terminal panes are arranged when you launch this workspace."
            )

            HStack {
                Spacer()
                WorkspaceLayoutPicker(
                    selected: project.layout,
                    onSelect: { layout in
                        store.setLayout(for: project, layout: layout)
                    }
                )
                Spacer()
            }

            HStack {
                Spacer()
                WorkspaceLayoutThumbnail(
                    layout: project.layout,
                    size: CGSize(
                        width: DevtailTokens.Sizes.layoutPreviewWidth,
                        height: DevtailTokens.Sizes.layoutPreviewHeight
                    ),
                    slotLabels: slotLabels(for: project),
                    onSlotMenu: { slot in
                        slotMenuContent(for: slot)
                    }
                )
                Spacer()
            }

        }
    }

    // MARK: - Section C: Panes

    @ViewBuilder
    private var panesSection: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapLarge) {
            SectionHeader(
                title: "PANES",
                guide: "Terminal sessions that will open when you launch this workspace."
            )

            if sortedPanes.isEmpty {
                emptyPanesView
            } else {
                VStack(spacing: DevtailTokens.Spacing.gapMedium) {
                    ForEach(sortedPanes, id: \.id) { pane in
                        PaneCard(
                            pane: pane,
                            branch: branchDetector.detectBranch(
                                in: URL(fileURLWithPath: project.directoryPath)
                                    .appendingPathComponent(pane.relativeCwd)
                            ),
                            slotLabel: pane.layoutSlot >= 0 ? "Slot \(pane.layoutSlot + 1)" : nil,
                            canDelete: sortedPanes.count > 1,
                            onEdit: { editingPaneID = pane.id },
                            onDelete: { store.deleteWorkspacePane(pane) }
                        )
                    }
                }
            }

            Button { isAddingPane = true } label: {
                Label("Add pane", systemImage: "plus")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(canAddPane ? DevtailTokens.Colors.textSecondary : DevtailTokens.Colors.textDisabled)
                    .padding(.horizontal, DevtailTokens.Spacing.gapLarge)
                    .padding(.vertical, DevtailTokens.Spacing.gapMedium)
                    .contentShape(
                        RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                            .stroke(DevtailTokens.Colors.borderSubtle, lineWidth: DevtailTokens.BorderWidth.default)
                    }
            }
            .buttonStyle(.plain)
            .disabled(!canAddPane)
            .help(canAddPane ? "Add a new terminal pane" : "Maximum of 4 panes reached")
        }
    }

    /// Add-pane is available when there's a project directory AND the
    /// pane count has not hit the Quarters layout ceiling (4).
    private var canAddPane: Bool {
        !project.directoryPath.isEmpty && sortedPanes.count < 4
    }

    // MARK: - Section D: Quick Links

    @ViewBuilder
    private var quickLinksSection: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapLarge) {
            SectionHeader(
                title: "QUICK LINKS",
                guide: "Bookmarks to URLs, files, or folders you access frequently for this project."
            )

            QuickLinksPanel(projectID: project.id)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var emptyPanesView: some View {
        VStack(spacing: DevtailTokens.Spacing.gapLarge) {
            Label(
                "No panes yet. Add your first terminal pane to get started.",
                systemImage: "info.circle"
            )
            .font(DevtailTokens.Typography.caption)
            .foregroundStyle(DevtailTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(DevtailTokens.Spacing.gapSection)
    }

    private func slotLabels(for project: Project) -> [Int: String] {
        var labels: [Int: String] = [:]
        for pane in sortedPanes where pane.layoutSlot >= 0 {
            labels[pane.layoutSlot] = pane.label
        }
        return labels
    }

    private func slotMenuContent(for slot: Int) -> AnyView {
        let currentLabel = slotLabels(for: project)[slot] ?? "—"
        return AnyView(
            Menu {
                ForEach(sortedPanes, id: \.id) { pane in
                    Button(pane.label) {
                        store.assignPaneToSlot(pane: pane, slot: slot)
                    }
                }
            } label: {
                Text(currentLabel)
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, DevtailTokens.Spacing.gapSmall)
            }
            .menuStyle(.borderlessButton)
        )
    }

    private func launchWorkspace() {
        store.launchWorkspace(for: project)
        activityMonitor.markLaunched(
            projectID: project.id,
            directoryPath: project.directoryPath
        )
    }
}
