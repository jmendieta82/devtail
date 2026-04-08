//
//  ComingSoonView.swift
//  Devtail
//
//  Reusable placeholder view for surfaces that are not yet implemented
//  (Settings now, future tabs/windows later). Feature-scoped for now;
//  promote to a shared folder when a second consumer arrives.
//

import SwiftUI

struct ComingSoonView: View {
    let title: String

    var body: some View {
        VStack(spacing: DevtailTokens.Spacing.gapLarge) {
            Image(systemName: "hammer")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
            Text(title)
                .font(DevtailTokens.Typography.titleMedium)
                .foregroundStyle(DevtailTokens.Colors.textPrimary)
            Text("Coming soon")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textMuted)
        }
        .padding(DevtailTokens.Spacing.gapXLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DevtailTokens.Colors.popoverBackground)
    }
}

#Preview {
    ComingSoonView(title: "Settings")
}
