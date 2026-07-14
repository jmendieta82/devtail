import SwiftUI

/// Pane row for the popover accordion.
/// Full-width horizontal layout: label + optional stack badge on the left,
/// optional branch on the right.
struct PaneChip: View {
    let label: String
    var stack: String? = nil
    var branch: String? = nil

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapMedium) {
            Text(label.uppercased())
                .font(DevtailTokens.Typography.captionSmall)
                .fontWeight(.semibold)
                .tracking(0.5)
                .foregroundStyle(DevtailTokens.Colors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let branch {
                Label(branch, systemImage: "arrow.triangle.branch")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .lineLimit(1)
            }

            if let stack, !stack.isEmpty {
                Text(stack)
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.accentPrimary)
                    .padding(.horizontal, DevtailTokens.Spacing.gapSmall)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: DevtailTokens.Radius.badge)
                            .fill(DevtailTokens.Colors.accentPrimary.opacity(DevtailTokens.ActiveState.badgeBgOpacity))
                    )
            }
        }
        .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
        .frame(maxWidth: .infinity)
        .glassEffect(in: RoundedRectangle(cornerRadius: DevtailTokens.Radius.chip))
    }
}
