//
//  AppSettingsTests.swift
//  DevtailTests
//
//  Unit tests for AppSettings. Uses injected UserDefaults instances (via
//  suiteName) so tests never touch UserDefaults.standard.
//

import Testing
import Foundation
@testable import Devtail

@MainActor
@Suite("AppSettings")
struct AppSettingsTests {

    private func freshDefaults(suffix: String = UUID().uuidString) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "AppSettingsTests-\(suffix)")!
        defaults.removePersistentDomain(forName: "AppSettingsTests-\(suffix)")
        return defaults
    }

    @Test("defaultLaunchTarget is .auto when UserDefaults key is absent")
    func defaultsToAutoWhenKeyAbsent() {
        let defaults = freshDefaults()
        // Key is deliberately not set — simulate a fresh install.
        let settings = AppSettings(defaults: defaults)
        #expect(settings.defaultLaunchTarget == .auto)
    }

    @Test("defaultLaunchTarget reads stored 'newWindow' value correctly")
    func readsStoredNewWindowValue() {
        let defaults = freshDefaults()
        defaults.set("newWindow", forKey: "defaultLaunchTarget")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.defaultLaunchTarget == .newWindow)
    }

    @Test("defaultLaunchTarget reads stored 'newTab' value correctly")
    func readsStoredNewTabValue() {
        let defaults = freshDefaults()
        defaults.set("newTab", forKey: "defaultLaunchTarget")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.defaultLaunchTarget == .newTab)
    }

    @Test("defaultLaunchTarget falls back to .auto for an unrecognised stored value")
    func fallsBackToAutoForUnknownStoredValue() {
        let defaults = freshDefaults()
        defaults.set("bogusValue", forKey: "defaultLaunchTarget")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.defaultLaunchTarget == .auto)
    }
}
