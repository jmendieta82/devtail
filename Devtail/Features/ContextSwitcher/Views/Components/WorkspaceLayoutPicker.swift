import SwiftUI

struct WorkspaceLayoutPicker: View {
    let selected: WorkspaceLayout
    let onSelect: (WorkspaceLayout) -> Void
    var axis: Axis = .horizontal
    var layouts: [WorkspaceLayout] = WorkspaceLayout.allCases

    var body: some View {
        Group {
            if axis == .vertical {
                VStack(spacing: DevtailTokens.Spacing.gapMedium) {
                    pickerItems
                }
            } else {
                HStack(spacing: DevtailTokens.Spacing.gapLarge) {
                    pickerItems
                }
            }
        }
    }

    @ViewBuilder
    private var pickerItems: some View {
        ForEach(layouts, id: \.self) { layout in
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
                                    ? DevtailTokens.Colors.accentPrimary
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
