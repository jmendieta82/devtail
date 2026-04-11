import SwiftUI

/// Project row for the dashboard sidebar.
/// Shows accent color strip, name, layout info, and activity dot.
struct DashboardSidebarItem: View {
    let project: Project
    let isSelected: Bool
    let isActive: Bool

    private var paneCount: Int {
        project.workspacePanes.count
    }

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapMedium) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(project.color.color)
                .frame(width: DevtailTokens.BorderWidth.accentStrip)
                .opacity(isSelected ? 1.0 : 0.5)

            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
                HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                    ColorDot(color: project.color, size: DevtailTokens.Sizes.projectDot)
                        .overlay(alignment: .bottomTrailing) {
                            ActivityDot(isActive: isActive)
                        }

                    Text(project.name)
                        .font(DevtailTokens.Typography.bodySemibold)
                        .foregroundStyle(DevtailTokens.Colors.textPrimary)
                        .lineLimit(1)
                }

                Text("\(project.layout.displayName) · \(paneCount) panes")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, DevtailTokens.Spacing.sidebarItemVertical)
        .padding(.trailing, DevtailTokens.Spacing.sidebarItemPadding)
        .contentShape(Rectangle())
        .glassEffect(.regular.interactive())
    }
}
