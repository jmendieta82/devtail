import SwiftUI

/// Single project row in the popover accordion.
/// Collapsed: color dot + name + pane count + chevron
/// Expanded: + pane chips + Resume (conditional) + Launch button + Configure link
/// Context menu (right-click on the header): Open in VSCode / Delete project…
struct PopoverAccordionItem: View {
    let project: Project
    let isExpanded: Bool
    let isActive: Bool
    let branches: [UUID: String]
    let onToggle: () -> Void
    let onLaunch: () -> Void
    let onResume: () -> Void
    let onOpenInVSCode: () -> Void
    let onDeleteProject: () -> Void
    let onOpenDashboard: () -> Void

    @State private var showDeleteConfirmation: Bool = false

    private var sortedPanes: [WorkspacePane] {
        project.workspacePanes.sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerButton
            if isExpanded {
                expandedContent
            }
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: DevtailTokens.Radius.card))
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .confirmationDialog(
            "Delete \(project.name)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete project", role: .destructive) {
                onDeleteProject()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete the project and all its workspace panes and quick links. This cannot be undone.")
        }
    }

    // MARK: - Header

    private var headerButton: some View {
        Button(action: onToggle) {
            HStack(spacing: DevtailTokens.Spacing.gapMedium) {
                ActivityDot(isActive: isActive)

                Text(project.name)
                    .font(DevtailTokens.Typography.bodySemibold)
                    .foregroundStyle(DevtailTokens.Colors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text("\(sortedPanes.count) panes")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
            }
            .padding(.horizontal, DevtailTokens.Spacing.cardPadding)
            .padding(.vertical, DevtailTokens.Spacing.sidebarItemVertical)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onOpenInVSCode()
            } label: {
                Label("Open in VSCode", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .disabled(project.directoryPath.isEmpty)

            Divider()

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete project…", systemImage: "trash")
            }
        }
    }

    // MARK: - Expanded

    private var expandedContent: some View {
        VStack(spacing: DevtailTokens.Spacing.gapLarge) {
            if !sortedPanes.isEmpty {
                VStack(spacing: DevtailTokens.Spacing.gapSmall) {
                    ForEach(sortedPanes, id: \.id) { pane in
                        PaneChip(
                            label: pane.label,
                            stack: pane.stack,
                            branch: branches[pane.id]
                        )
                    }
                }
            }

            if project.lastLaunchedAt != nil {
                Button(action: onResume) {
                    HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                        Image(systemName: "arrow.uturn.forward")
                        Text("Resume")
                    }
                    .font(DevtailTokens.Typography.bodySmall)
                    .foregroundStyle(DevtailTokens.Colors.accentPrimary.opacity(0.85))
                    .frame(maxWidth: .infinity)
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

            Button(action: onLaunch) {
                HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                    Image(systemName: "play.fill")
                    Text("Launch")
                }
                .font(DevtailTokens.Typography.bodySemibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: DevtailTokens.Sizes.launchButtonHeight)
                .background(
                    RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                        .fill(DevtailTokens.Colors.accentPrimary)
                )
                .glassEffect(
                    .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                )
            }
            .buttonStyle(.plain)
            .disabled(sortedPanes.isEmpty || project.directoryPath.isEmpty)
            .help("Launch workspace")

            Button(action: onOpenDashboard) {
                Text("View in Dashboard...")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Open the dashboard with this project selected")
        }
        .padding(.horizontal, DevtailTokens.Spacing.cardPadding)
        .padding(.bottom, DevtailTokens.Spacing.cardPadding)
    }
}
