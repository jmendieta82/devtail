//
//  EnvironmentPill.swift
//  Devtail
//
//  Read-only badge displaying an environment. Used in the workspace
//  pane row (compact variant) — Project no longer has an environment
//  field, the badge is now per-pane.
//
//  Color mapping:
//  - dev:     muted (textSecondary on pill bg)
//  - staging: orange tint
//  - prod:    green tint
//
//  The `compact` variant uses smaller padding and `captionSmall`
//  typography so the pill can sit alongside the stack and branch
//  badges in the pane row without dominating them.
//

import SwiftUI

struct EnvironmentPill: View {
    let environment: ProjectEnvironment
    var compact: Bool = false

    var body: some View {
        Text(environment.displayName)
            .font(compact
                  ? DevtailTokens.Typography.captionSmall
                  : DevtailTokens.Typography.micro)
            .foregroundStyle(foreground)
            .padding(.horizontal,
                     compact
                        ? DevtailTokens.Spacing.gapSmall
                        : DevtailTokens.Spacing.gapMedium)
            .padding(.vertical,
                     compact ? 1 : DevtailTokens.Spacing.gapTiny)
            .background(
                RoundedRectangle(cornerRadius: DevtailTokens.Radius.pill)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DevtailTokens.Radius.pill)
                    .stroke(border, lineWidth: DevtailTokens.BorderWidth.default)
            )
    }

    private var background: Color {
        switch environment {
        case .dev:
            return DevtailTokens.Colors.pill
        case .staging:
            return DevtailTokens.Colors.accentOrange
                .opacity(DevtailTokens.ActiveState.badgeBgOpacity)
        case .prod:
            return DevtailTokens.Colors.accentPrimary
                .opacity(DevtailTokens.ActiveState.badgeBgOpacity)
        }
    }

    private var border: Color {
        switch environment {
        case .dev:
            return DevtailTokens.Colors.borderSubtle
        case .staging:
            return DevtailTokens.Colors.accentOrange
                .opacity(DevtailTokens.ActiveState.activeBorderOpacity)
        case .prod:
            return DevtailTokens.Colors.accentPrimary
                .opacity(DevtailTokens.ActiveState.activeBorderOpacity)
        }
    }

    private var foreground: Color {
        switch environment {
        case .dev:
            return DevtailTokens.Colors.textSecondary
        case .staging:
            return DevtailTokens.Colors.accentOrange
        case .prod:
            return DevtailTokens.Colors.accentPrimary
        }
    }
}

#Preview {
    HStack(spacing: DevtailTokens.Spacing.gapMedium) {
        EnvironmentPill(environment: .dev)
        EnvironmentPill(environment: .staging)
        EnvironmentPill(environment: .prod)
    }
    .padding()
    .background(DevtailTokens.Colors.popoverBackground)
}
