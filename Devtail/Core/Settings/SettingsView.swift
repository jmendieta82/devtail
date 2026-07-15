//
//  SettingsView.swift
//  Devtail
//
//  Real settings pane (replaces the ComingSoon placeholder).
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Agent") {
                TextField("Agent command", text: $settings.agentCommand)
                    .font(DevtailTokens.Typography.mono)
                Text("Launched in the agent tab when a workspace opens. Example: claude --continue")
                    .font(.caption)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
    }
}
