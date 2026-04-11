import SwiftUI

/// Reusable section header with title and guide text.
/// Used across dashboard sections for consistent visual hierarchy.
///
/// Usage:
///     SectionHeader(title: "LAYOUT", guide: "Choose how your terminal panes are arranged.")
struct SectionHeader: View {
    let title: String
    var guide: String? = nil

    init(title: String = "", guide: String? = nil) {
        self.title = title
        self.guide = guide
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSectionTitle) {
            if !title.isEmpty {
                Text(title)
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .tracking(0.5)
            }

            if let guide {
                Label(guide, systemImage: "info.circle")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
            }
        }
    }
}
