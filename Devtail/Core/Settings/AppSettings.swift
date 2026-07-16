//
//  AppSettings.swift
//  Devtail
//
//  Global app-level preferences backed by UserDefaults. Read once at init;
//  no live KVO — the Settings UI is out of scope for this change.
//  `defaultLaunchTarget` is dormant: the AppleScript/Ghostty launcher that
//  consumed it was retired in favor of the embedded workspace window, but
//  the setting is kept on the model per spec for potential future use.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    private let defaults: UserDefaults
    var defaultLaunchTarget: LaunchTarget
    var agentCommand: String {
        didSet { defaults.set(agentCommand, forKey: "agentCommand") }
    }

    // MARK: - Terminal appearance

    /// Defaults below mirror Javier's Ghostty config.
    var terminalThemeId: String {
        didSet { defaults.set(terminalThemeId, forKey: "terminalThemeId") }
    }
    var terminalFontName: String {
        didSet { defaults.set(terminalFontName, forKey: "terminalFontName") }
    }
    var terminalFontSize: Double {
        didSet { defaults.set(terminalFontSize, forKey: "terminalFontSize") }
    }
    var terminalCursorBlock: Bool {
        didSet { defaults.set(terminalCursorBlock, forKey: "terminalCursorBlock") }
    }
    var terminalCursorBlinks: Bool {
        didSet { defaults.set(terminalCursorBlinks, forKey: "terminalCursorBlinks") }
    }
    var terminalCopyOnSelect: Bool {
        didSet { defaults.set(terminalCopyOnSelect, forKey: "terminalCopyOnSelect") }
    }
    var terminalHideMouseWhileTyping: Bool {
        didSet { defaults.set(terminalHideMouseWhileTyping, forKey: "terminalHideMouseWhileTyping") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: "defaultLaunchTarget") ?? LaunchTarget.auto.rawValue
        self.defaultLaunchTarget = LaunchTarget(rawValue: raw) ?? .auto

        let rawCommand = defaults.string(forKey: "agentCommand") ?? ""
        self.agentCommand = rawCommand.trimmingCharacters(in: .whitespaces).isEmpty ? "claude" : rawCommand

        self.terminalThemeId = defaults.string(forKey: "terminalThemeId") ?? "catppuccin-mocha"
        self.terminalFontName = defaults.string(forKey: "terminalFontName") ?? "JetBrainsMono-Regular"
        self.terminalFontSize = (defaults.object(forKey: "terminalFontSize") as? Double) ?? 14
        self.terminalCursorBlock = (defaults.object(forKey: "terminalCursorBlock") as? Bool) ?? true
        self.terminalCursorBlinks = (defaults.object(forKey: "terminalCursorBlinks") as? Bool) ?? false
        self.terminalCopyOnSelect = (defaults.object(forKey: "terminalCopyOnSelect") as? Bool) ?? true
        self.terminalHideMouseWhileTyping = (defaults.object(forKey: "terminalHideMouseWhileTyping") as? Bool) ?? true
    }
}
