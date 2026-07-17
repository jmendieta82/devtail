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

    @Test("agentCommand defaults to claude")
    func agentCommandDefaultsToClaude() {
        let settings = AppSettings(defaults: freshDefaults())
        #expect(settings.agentCommand == "claude")
    }

    @Test("agentCommand reads stored value")
    func agentCommandReadsStoredValue() {
        let defaults = freshDefaults()
        defaults.set("claude --continue", forKey: "agentCommand")
        #expect(AppSettings(defaults: defaults).agentCommand == "claude --continue")
    }

    @Test("agentCommand blank stored value falls back to claude")
    func agentCommandBlankStoredValueFallsBackToClaude() {
        let defaults = freshDefaults()
        defaults.set("   ", forKey: "agentCommand")
        #expect(AppSettings(defaults: defaults).agentCommand == "claude")
    }

    @Test("agentCommand persists on change")
    func agentCommandPersistsOnChange() {
        let defaults = freshDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.agentCommand = "claude --continue"
        #expect(defaults.string(forKey: "agentCommand") == "claude --continue")
    }

    // MARK: - Terminal appearance defaults

    @Test("terminal appearance fields default to Javier's Ghostty config when keys are absent")
    func terminalAppearanceDefaultsWhenKeysAbsent() {
        let settings = AppSettings(defaults: freshDefaults())
        #expect(settings.terminalThemeId == "catppuccin-mocha")
        #expect(settings.terminalFontName == "JetBrainsMono-Regular")
        #expect(settings.terminalFontSize == 14)
        #expect(settings.terminalCursorBlock == true)
        #expect(settings.terminalCursorBlinks == false)
        #expect(settings.terminalCopyOnSelect == true)
        #expect(settings.terminalHideMouseWhileTyping == true)
    }

    @Test("terminal appearance fields read persisted values")
    func terminalAppearanceReadsStoredValues() {
        let defaults = freshDefaults()
        defaults.set("dracula", forKey: "terminalThemeId")
        defaults.set("Menlo-Regular", forKey: "terminalFontName")
        defaults.set(16.0, forKey: "terminalFontSize")
        defaults.set(false, forKey: "terminalCursorBlock")
        defaults.set(true, forKey: "terminalCursorBlinks")
        defaults.set(false, forKey: "terminalCopyOnSelect")
        defaults.set(false, forKey: "terminalHideMouseWhileTyping")

        let settings = AppSettings(defaults: defaults)

        #expect(settings.terminalThemeId == "dracula")
        #expect(settings.terminalFontName == "Menlo-Regular")
        #expect(settings.terminalFontSize == 16)
        #expect(settings.terminalCursorBlock == false)
        #expect(settings.terminalCursorBlinks == true)
        #expect(settings.terminalCopyOnSelect == false)
        #expect(settings.terminalHideMouseWhileTyping == false)
    }

    @Test("terminal appearance fields persist on change")
    func terminalAppearanceFieldsPersistOnChange() {
        let defaults = freshDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.terminalThemeId = "one-dark"
        settings.terminalFontName = "Menlo-Regular"
        settings.terminalFontSize = 18
        settings.terminalCursorBlock = false
        settings.terminalCursorBlinks = true
        settings.terminalCopyOnSelect = false
        settings.terminalHideMouseWhileTyping = false

        #expect(defaults.string(forKey: "terminalThemeId") == "one-dark")
        #expect(defaults.string(forKey: "terminalFontName") == "Menlo-Regular")
        #expect(defaults.double(forKey: "terminalFontSize") == 18)
        #expect(defaults.bool(forKey: "terminalCursorBlock") == false)
        #expect(defaults.bool(forKey: "terminalCursorBlinks") == true)
        #expect(defaults.bool(forKey: "terminalCopyOnSelect") == false)
        #expect(defaults.bool(forKey: "terminalHideMouseWhileTyping") == false)
    }

    // MARK: - Interface text size

    @Test("uiFontSize defaults to 12 when UserDefaults key is absent")
    func uiFontSizeDefaultsWhenKeyAbsent() {
        let settings = AppSettings(defaults: freshDefaults())
        #expect(settings.uiFontSize == 12)
    }

    @Test("uiFontSize reads persisted value")
    func uiFontSizeReadsStoredValue() {
        let defaults = freshDefaults()
        defaults.set(15.0, forKey: "uiFontSize")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.uiFontSize == 15)
    }

    @Test("uiFontSize persists on change")
    func uiFontSizePersistsOnChange() {
        let defaults = freshDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.uiFontSize = 16
        #expect(defaults.double(forKey: "uiFontSize") == 16)
    }

    @Test("uiFontSize keeps DevtailTokens.Typography.baseSize in sync on init and on change")
    func uiFontSizeSyncsTypographyBaseSize() {
        let defaults = freshDefaults()
        defaults.set(11.0, forKey: "uiFontSize")
        let settings = AppSettings(defaults: defaults)
        #expect(DevtailTokens.Typography.baseSize == 11)

        settings.uiFontSize = 16
        #expect(DevtailTokens.Typography.baseSize == 16)

        DevtailTokens.Typography.baseSize = 12
    }
}
