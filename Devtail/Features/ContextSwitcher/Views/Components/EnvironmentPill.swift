//
//  EnvironmentPill.swift
//  Devtail
//
//  Read-only badge displaying a project's environment. Used in the
//  project row. Color mapping:
//  - dev:     muted (textSecondary on pill bg)
//  - staging: orange tint
//  - prod:    green tint
//

import SwiftUI

struct EnvironmentPill: View {
    let environment: ProjectEnvironment

    var body: some View {
        Text(environment.displayName)
            .font(DevtailTokens.Typography.micro)
            .foregroundStyle(foreground)
            .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
            .padding(.vertical, DevtailTokens.Spacing.gapTiny)
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
            return DevtailTokens.Colors.accentGreen
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
            return DevtailTokens.Colors.accentGreen
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
            return DevtailTokens.Colors.accentGreen
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
