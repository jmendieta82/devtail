import SwiftUI

/// Single project row in the popover accordion.
/// Collapsed: color dot + name + pane count + chevron
/// Expanded: + pane chips + Launch button + Configure link
struct PopoverAccordionItem: View {
    let project: Project
    let isExpanded: Bool
    let isActive: Bool
    let branches: [UUID: String]
    let onToggle: () -> Void
    let onLaunch: () -> Void
    let onOpenDashboard: () -> Void
    var isLaunching: Bool = false

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
    }

    // MARK: - Header

    private var headerButton: some View {
        Button(action: onToggle) {
            HStack(spacing: DevtailTokens.Spacing.gapMedium) {
                ColorDot(color: project.color, size: DevtailTokens.Sizes.projectDot)
                    .overlay(alignment: .bottomTrailing) {
                        ActivityDot(isActive: isActive)
                    }

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

            Button(action: onLaunch) {
                HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                    Image(systemName: isLaunching ? "hourglass" : "play.fill")
                    Text(isLaunching ? "Launching..." : "Launch")
                }
                .font(DevtailTokens.Typography.bodySemibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: DevtailTokens.Sizes.launchButtonHeight)
                .background(
                    RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                        .fill(DevtailTokens.Colors.accentGreen)
                )
                .glassEffect(
                    .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                )
            }
            .buttonStyle(.plain)
            .disabled(isLaunching || sortedPanes.isEmpty || project.directoryPath.isEmpty)
            .help("Launch workspace in Ghostty")

            Button(action: onOpenDashboard) {
                Text("Configure in Dashboard...")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Open full dashboard to configure this workspace")
        }
        .padding(.horizontal, DevtailTokens.Spacing.cardPadding)
        .padding(.bottom, DevtailTokens.Spacing.cardPadding)
    }
}
