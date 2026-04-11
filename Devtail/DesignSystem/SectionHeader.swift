import SwiftUI

/// Reusable section header with title and optional guide text (shown as tooltip).
/// The guide text is NOT rendered inline anymore — it lives in a `.help()`
/// attached to an info.circle icon next to the title, so it stays accessible
/// without visually competing with the content.
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
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            if !title.isEmpty {
                Text(title)
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .tracking(0.5)
            }

            if let guide {
                Image(systemName: "info.circle")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary.opacity(0.5))
                    .help(guide)
            }
        }
    }
}
