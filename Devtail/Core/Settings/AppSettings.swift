//
//  AppSettings.swift
//  Devtail
//
//  Global app-level preferences backed by UserDefaults. Read once at init;
//  no live KVO — the Settings UI is out of scope for this change.
//  Injected into WorkspaceLauncher via init so tests can supply a custom
//  UserDefaults instance without touching the real store.
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
