//
//  AppSettingsPane.swift
//  Devtail
//
//  Application-wide settings (Agent, Terminal), mounted inside the
//  workspace settings tab's "Application" scope. Extracted from the
//  retired standalone Settings window so the same controls now live
//  next to the project-scoped settings.
//

import SwiftUI

struct AppSettingsPane: View {
    @Environment(AppSettings.self) private var settings

    private var fontFamilies: [MonospaceFontCatalog.FontChoice] {
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
                    ForEach(fontFamilies) { choice in
                        Text(choice.displayName)
                            .font(.custom(choice.faceName, size: 12))
                            .tag(choice.faceName)
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
    }
}
