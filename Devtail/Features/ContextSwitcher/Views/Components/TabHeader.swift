//
//  TabHeader.swift
//  Devtail
//
//  Custom HStack of 3 tab buttons for the MenuBarExtra popover header.
//  We deliberately do NOT use Picker(.segmented) (fights dark theme tokens)
//  or TabView (heavy chrome, can't disable per-tab gracefully).
//

import SwiftUI

enum ContextSwitcherTab: String, Hashable, CaseIterable, Identifiable {
    case projects
    case secrets
    case aws

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .projects: return "Projects"
        case .secrets:  return "Secrets"
        case .aws:      return "AWS"
        }
    }

    var isEnabled: Bool { self == .projects }
}

struct TabHeader: View {
    @Binding var selectedTab: ContextSwitcherTab

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            ForEach(ContextSwitcherTab.allCases) { tab in
                Button {
                    guard tab.isEnabled else { return }
                    selectedTab = tab
                } label: {
                    Text(tab.displayName)
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(foreground(for: tab))
                        .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
                        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
                        .background(
                            RoundedRectangle(cornerRadius: DevtailTokens.Radius.tab)
                                .fill(
                                    selectedTab == tab && tab.isEnabled
                                        ? DevtailTokens.Colors.hoverState
                                        : Color.clear
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(!tab.isEnabled)
                .help(tab.isEnabled ? "" : "Coming soon")
            }
        }
    }

    private func foreground(for tab: ContextSwitcherTab) -> Color {
        guard tab.isEnabled else {
            return DevtailTokens.Colors.textDisabled
        }
        return selectedTab == tab
            ? DevtailTokens.Colors.textPrimary
            : DevtailTokens.Colors.textSecondary
    }
}

private struct TabHeaderPreviewHost: View {
    @State private var selected: ContextSwitcherTab = .projects

    var body: some View {
        TabHeader(selectedTab: $selected)
            .padding()
            .background(DevtailTokens.Colors.popoverBackground)
    }
}

#Preview {
    TabHeaderPreviewHost()
}
