//
//  SettingsView.swift
//  Devtail
//
//  Real settings pane (replaces the ComingSoon placeholder).
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    private var fontFamilies: [String] {
        MonospaceFontCatalog.families()
    }

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

            Section("Terminal") {
                TerminalThemePicker(selectedThemeId: $settings.terminalThemeId)

                Picker("Font", selection: $settings.terminalFontName) {
                    ForEach(fontFamilies, id: \.self) { name in
                        Text(name)
                            .font(.custom(name, size: 12))
                            .tag(name)
                    }
                }

                Stepper(
                    "Font size: \(Int(settings.terminalFontSize))",
                    value: $settings.terminalFontSize,
                    in: 10...20
                )

                Toggle("Block cursor", isOn: $settings.terminalCursorBlock)
                Toggle("Blink cursor", isOn: $settings.terminalCursorBlinks)
                Toggle("Copy on select", isOn: $settings.terminalCopyOnSelect)
                Toggle("Hide mouse while typing", isOn: $settings.terminalHideMouseWhileTyping)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .padding()
    }
}
