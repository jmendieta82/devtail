//
//  ColorPickerRow.swift
//  Devtail
//
//  Horizontal row of 7 selectable color dots used by ProjectFormView.
//  Selection is indicated by an outer white-stroke halo so the dot's color
//  isn't visually shrunk.
//

import SwiftUI

struct ColorPickerRow: View {
    @Binding var selection: ProjectColor

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapLarge) {
            ForEach(ProjectColor.allCases) { color in
                ZStack {
                    Circle()
                        .stroke(
                            selection == color
                                ? DevtailTokens.Colors.textPrimary
                                : Color.clear,
                            lineWidth: 2
                        )
                        .frame(
                            width: DevtailTokens.Sizes.colorPickerDot + 6,
                            height: DevtailTokens.Sizes.colorPickerDot + 6
                        )
                    Circle()
                        .fill(color.color)
                        .frame(
                            width: DevtailTokens.Sizes.colorPickerDot,
                            height: DevtailTokens.Sizes.colorPickerDot
                        )
                }
                .contentShape(Circle())
                .onTapGesture { selection = color }
                .accessibilityLabel("\(color.rawValue) color")
                .accessibilityAddTraits(selection == color ? .isSelected : [])
            }
        }
        .animation(.smooth(duration: 0.15), value: selection)
    }
}

private struct ColorPickerRowPreviewHost: View {
    @State private var selection: ProjectColor = .blue

    var body: some View {
        ColorPickerRow(selection: $selection)
            .padding()
            .background(DevtailTokens.Colors.popoverBackground)
    }
}

#Preview {
    ColorPickerRowPreviewHost()
}
