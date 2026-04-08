//
//  EnvironmentPicker.swift
//  Devtail
//
//  Clickable chips selector for ProjectEnvironment. Visually similar to
//  EnvironmentPill but tinted accent-green when selected. Used by
//  ProjectFormView.
//

import SwiftUI

struct EnvironmentPicker: View {
    @Binding var selection: ProjectEnvironment

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            ForEach(ProjectEnvironment.allCases) { env in
                Button {
                    selection = env
                } label: {
                    Text(env.displayName)
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(foreground(for: env))
                        .padding(.horizontal, DevtailTokens.Spacing.gapLarge)
                        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
                        .background(
                            RoundedRectangle(cornerRadius: DevtailTokens.Radius.pill)
                                .fill(background(for: env))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DevtailTokens.Radius.pill)
                                .stroke(
                                    border(for: env),
                                    lineWidth: DevtailTokens.BorderWidth.default
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func foreground(for env: ProjectEnvironment) -> Color {
        selection == env
            ? DevtailTokens.Colors.textPrimary
            : DevtailTokens.Colors.textSecondary
    }

    private func background(for env: ProjectEnvironment) -> Color {
        selection == env
            ? DevtailTokens.Colors.accentGreen
                .opacity(DevtailTokens.ActiveState.badgeBgOpacity)
            : DevtailTokens.Colors.pill
    }

    private func border(for env: ProjectEnvironment) -> Color {
        selection == env
            ? DevtailTokens.Colors.accentGreen
                .opacity(DevtailTokens.ActiveState.activeBorderOpacity)
            : DevtailTokens.Colors.borderSubtle
    }
}

private struct EnvironmentPickerPreviewHost: View {
    @State private var selection: ProjectEnvironment = .dev

    var body: some View {
        EnvironmentPicker(selection: $selection)
            .padding()
            .background(DevtailTokens.Colors.popoverBackground)
    }
}

#Preview {
    EnvironmentPickerPreviewHost()
}
