import SwiftUI

/// Project row for the dashboard sidebar.
/// Shows name, layout info, activity dot, and a "last seen" timestamp chip.
struct DashboardSidebarItem: View {
    let project: Project
    let isSelected: Bool
    let isActive: Bool

    private var paneCount: Int {
        project.workspacePanes.count
    }

    private var lastSeenLabel: String? {
        RelativeDateFormatter.label(for: project.lastLaunchedAt)
    }

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapMedium) {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
                HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                    ActivityDot(isActive: isActive)

                    Text(project.name)
                        .font(DevtailTokens.Typography.bodySemibold)
                        .foregroundStyle(DevtailTokens.Colors.textPrimary)
                        .lineLimit(1)
                }

                HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                    Text("\(project.layout.displayName) · \(paneCount) panes")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                        .lineLimit(1)

                    if let label = lastSeenLabel {
                        Text("·")
                            .font(DevtailTokens.Typography.captionSmall)
                            .foregroundStyle(DevtailTokens.Colors.textMuted)

                        Text(label)
                            .font(DevtailTokens.Typography.captionSmall)
                            .foregroundStyle(DevtailTokens.Colors.textMuted)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.leading, DevtailTokens.Spacing.gapMedium)
        .padding(.trailing, DevtailTokens.Spacing.sidebarItemPadding)
        .padding(.vertical, DevtailTokens.Spacing.sidebarItemVertical)
        .contentShape(Rectangle())
        .glassEffect(
            .regular.interactive(),
            in: RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
        )
    }
}
