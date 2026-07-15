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
    var defaultLaunchTarget: LaunchTarget

    init(defaults: UserDefaults = .standard) {
        let raw = defaults.string(forKey: "defaultLaunchTarget") ?? LaunchTarget.auto.rawValue
        self.defaultLaunchTarget = LaunchTarget(rawValue: raw) ?? .auto
    }
}
