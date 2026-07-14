//
//  EmptyProjectsView.swift
//  Devtail
//
//  Custom empty state shown inside MenuBarRootView when there are no projects.
//  Replaces the previous use of ContentUnavailableView, which fights our
//  custom dark tokens.
//

import SwiftUI

struct EmptyProjectsView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: DevtailTokens.Spacing.gapLarge) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(DevtailTokens.Colors.textTertiary)

            VStack(spacing: DevtailTokens.Spacing.gapSmall) {
                Text("No projects yet")
                    .font(DevtailTokens.Typography.titleMedium)
                    .foregroundStyle(DevtailTokens.Colors.textPrimary)
                Text("Add your first project to start switching contexts, managing secrets, and tracking costs.")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DevtailTokens.Spacing.gapXLarge)
            }

            Button {
                onCreate()
            } label: {
                Text("Create first project")
                    .font(DevtailTokens.Typography.bodyDefault)
                    .padding(.horizontal, DevtailTokens.Spacing.gapXLarge)
                    .padding(.vertical, DevtailTokens.Spacing.gapMedium)
                    .background(
                        RoundedRectangle(cornerRadius: DevtailTokens.Radius.tab)
                            .fill(DevtailTokens.Colors.accentPrimary)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Text("or press ⌘N anywhere")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
        }
        .padding(.vertical, DevtailTokens.Spacing.gapXLarge)
        .frame(maxWidth: .infinity, minHeight: 260)
    }
}

#Preview {
    EmptyProjectsView(onCreate: {})
        .frame(width: DevtailTokens.Sizes.popoverWidth)
        .background(DevtailTokens.Colors.popoverBackground)
}
