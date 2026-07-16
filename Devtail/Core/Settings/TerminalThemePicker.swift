//
//  TerminalThemePicker.swift
//  Devtail
//
//  Visual theme selector for the Terminal settings section: each built-in
//  theme is a clickable row with its name and a swatch preview, no raw
//  color-code entry.
//

import SwiftUI

struct TerminalThemePicker: View {
    @Binding var selectedThemeId: String

    var body: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
            ForEach(TerminalTheme.builtIn, id: \.id) { theme in
                themeRow(theme)
            }
        }
    }

    private func themeRow(_ theme: TerminalTheme) -> some View {
        let isSelected = theme.id == selectedThemeId

        return Button {
            selectedThemeId = theme.id
        } label: {
            HStack(spacing: DevtailTokens.Spacing.gapMedium) {
                Text(theme.name)
                    .font(DevtailTokens.Typography.body)
                    .foregroundStyle(DevtailTokens.Colors.textPrimary)

                Spacer()

                swatches(theme)

                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DevtailTokens.Colors.accentPrimary)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.vertical, DevtailTokens.Spacing.gapSmall)
            .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
            .background(
                RoundedRectangle(cornerRadius: DevtailTokens.Radius.chip)
                    .fill(isSelected ? Color.activeProjectBg : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func swatches(_ theme: TerminalTheme) -> some View {
        let representative = [theme.background, theme.ansi[1], theme.ansi[2], theme.ansi[3], theme.ansi[4], theme.ansi[5], theme.ansi[6]]
        return HStack(spacing: DevtailTokens.Spacing.gapTiny) {
            ForEach(Array(representative.enumerated()), id: \.offset) { _, color in
                Circle()
                    .fill(swiftUIColor(color))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle().strokeBorder(DevtailTokens.Colors.borderSubtle, lineWidth: 0.5)
                    )
            }
        }
    }

    private func swiftUIColor(_ color: ThemeColor) -> Color {
        Color(
            red: Double(color.red) / 255,
            green: Double(color.green) / 255,
            blue: Double(color.blue) / 255
        )
    }
}
