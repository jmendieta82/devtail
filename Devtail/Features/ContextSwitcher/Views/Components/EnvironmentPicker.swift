//
//  EnvironmentPicker.swift
//  Devtail
//
//  Clickable chips selector for an optional ProjectEnvironment. Renders
//  a leading "None" chip plus one chip per environment case. Tapping
//  "None" sets the binding to nil. Used today by WorkspacePaneEditRow —
//  panes have an optional environment because not every pane corresponds
//  to a runtime stage (some are notes, monitors, REPLs, …).
//

import SwiftUI

struct EnvironmentPicker: View {
    @Binding var selection: ProjectEnvironment?

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            // Leading "None" chip — clears the selection. Placed first
            // so a user scanning left-to-right sees the opt-out before
            // the value chips.
            Button {
                selection = nil
            } label: {
                Text("None")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(foregroundForNone)
                    .padding(.horizontal, DevtailTokens.Spacing.gapLarge)
                    .padding(.vertical, DevtailTokens.Spacing.gapSmall)
                    .background(
                        RoundedRectangle(cornerRadius: DevtailTokens.Radius.pill)
                            .fill(backgroundForNone)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DevtailTokens.Radius.pill)
                            .stroke(
                                borderForNone,
                                lineWidth: DevtailTokens.BorderWidth.default
                            )
                    )
            }
            .buttonStyle(.plain)

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

    private var foregroundForNone: Color {
        selection == nil
            ? DevtailTokens.Colors.textPrimary
            : DevtailTokens.Colors.textSecondary
    }

    private var backgroundForNone: Color {
        selection == nil
            ? DevtailTokens.Colors.accentGreen
                .opacity(DevtailTokens.ActiveState.badgeBgOpacity)
            : DevtailTokens.Colors.pill
    }

    private var borderForNone: Color {
        selection == nil
            ? DevtailTokens.Colors.accentGreen
                .opacity(DevtailTokens.ActiveState.activeBorderOpacity)
            : DevtailTokens.Colors.borderSubtle
    }
}

private struct EnvironmentPickerPreviewHost: View {
    @State private var selection: ProjectEnvironment? = nil

    var body: some View {
        EnvironmentPicker(selection: $selection)
            .padding()
            .background(DevtailTokens.Colors.popoverBackground)
    }
}

#Preview {
    EnvironmentPickerPreviewHost()
}
