import SwiftUI

/// Compact pane pill for the popover accordion.
/// Shows label + optional branch in a small chip.
struct PaneChip: View {
    let label: String
    var branch: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
            Text(label)
                .font(DevtailTokens.Typography.captionSmall)
                .fontWeight(.semibold)
                .foregroundStyle(DevtailTokens.Colors.textPrimary)
                .lineLimit(1)

            if let branch {
                Label(branch, systemImage: "arrow.triangle.branch")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
        .glassEffect()
    }
}
