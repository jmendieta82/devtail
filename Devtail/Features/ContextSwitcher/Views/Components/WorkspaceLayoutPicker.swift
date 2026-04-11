import SwiftUI

struct WorkspaceLayoutPicker: View {
    let selected: WorkspaceLayout
    let onSelect: (WorkspaceLayout) -> Void

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapLarge) {
            ForEach(WorkspaceLayout.allCases, id: \.self) { layout in
                Button { onSelect(layout) } label: {
                    VStack(spacing: DevtailTokens.Spacing.gapSmall) {
                        WorkspaceLayoutThumbnail(
                            layout: layout,
                            size: CGSize(
                                width: DevtailTokens.Sizes.layoutThumbnailWidth,
                                height: DevtailTokens.Sizes.layoutThumbnailHeight
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: DevtailTokens.Radius.chip)
                                .stroke(
                                    selected == layout
                                        ? DevtailTokens.Colors.accentGreen
                                        : DevtailTokens.Colors.borderSubtle,
                                    lineWidth: selected == layout ? 2 : DevtailTokens.BorderWidth.default
                                )
                        }

                        Text(layout.displayName)
                            .font(DevtailTokens.Typography.caption)
                            .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .help(layout.displayName)
            }
        }
    }
}
