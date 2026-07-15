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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: "defaultLaunchTarget") ?? LaunchTarget.auto.rawValue
        self.defaultLaunchTarget = LaunchTarget(rawValue: raw) ?? .auto

        let rawCommand = defaults.string(forKey: "agentCommand") ?? ""
        self.agentCommand = rawCommand.trimmingCharacters(in: .whitespaces).isEmpty ? "claude" : rawCommand
    }
}
