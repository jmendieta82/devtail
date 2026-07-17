//
//  SearchField.swift
//  Devtail
//
//  Plain TextField with a leading magnifier icon and a token-driven background.
//  Used inside MenuBarRootView. We deliberately do NOT use SwiftUI's
//  `.searchable()` because it expects a NavigationStack and misbehaves inside
//  MenuBarExtra(.window) popovers.
//

import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "Search projects"
    /// Optional external focus binding — the workspace files panel drives
    /// focus programmatically (Cmd+P); menu bar usage passes nothing.
    var focus: FocusState<Bool>.Binding?

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapMedium) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: DevtailTokens.Sizes.searchIconSize))
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
            if let focus {
                textField.focused(focus)
            } else {
                textField
            }
        }
        .padding(.horizontal, DevtailTokens.Spacing.gapLarge)
        .padding(.vertical, DevtailTokens.Spacing.searchVertical)
        .background(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.searchField)
                .fill(DevtailTokens.Colors.searchField)
        )
    }

    private var textField: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(DevtailTokens.Typography.bodySmall)
            .foregroundStyle(DevtailTokens.Colors.textPrimary)
    }
}

private struct SearchFieldPreviewHost: View {
    @State private var empty: String = ""
    @State private var withText: String = "devtail"

    var body: some View {
        VStack(spacing: DevtailTokens.Spacing.gapLarge) {
            SearchField(text: $empty)
            SearchField(text: $withText)
        }
        .padding()
        .background(DevtailTokens.Colors.popoverBackground)
    }
}

#Preview {
    SearchFieldPreviewHost()
}
