import SwiftUI

/// Pane row for the popover accordion.
/// Full-width horizontal layout: label on the left, optional branch on the right.
struct PaneChip: View {
    let label: String
    var branch: String? = nil

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapMedium) {
            Text(label)
                .font(DevtailTokens.Typography.captionSmall)
                .fontWeight(.semibold)
                .foregroundStyle(DevtailTokens.Colors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let branch {
                Label(branch, systemImage: "arrow.triangle.branch")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
        .frame(maxWidth: .infinity)
        .glassEffect(in: RoundedRectangle(cornerRadius: DevtailTokens.Radius.chip))
    }
}
