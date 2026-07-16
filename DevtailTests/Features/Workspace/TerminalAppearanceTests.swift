//
//  TerminalAppearanceTests.swift
//  DevtailTests
//

import Testing
import AppKit
@testable import Devtail

@MainActor
@Suite("TerminalAppearance")
struct TerminalAppearanceTests {

    private func freshSettings(suffix: String = UUID().uuidString) -> AppSettings {
        let defaults = UserDefaults(suiteName: "TerminalAppearanceTests-\(suffix)")!
        defaults.removePersistentDomain(forName: "TerminalAppearanceTests-\(suffix)")
        return AppSettings(defaults: defaults)
    }

    @Test("resolveFont falls back to a monospaced system font for an unknown font name")
    func resolveFontFallsBackForUnknownName() {
        let font = TerminalAppearance.resolveFont(name: "Definitely-Not-A-Real-Font-Name", size: 14)
        #expect(font.isFixedPitch)
    }

    @Test("resolveFont resolves a known font name")
    func resolveFontResolvesKnownName() {
        let font = TerminalAppearance.resolveFont(name: "Menlo-Regular", size: 13)
        #expect(font.fontName == "Menlo-Regular")
        #expect(font.pointSize == 13)
    }

    @Test("token is stable for equal settings")
    func tokenStableForEqualSettings() {
        let settings = freshSettings()
        let a = TerminalAppearance(settings: settings)
        let b = TerminalAppearance(settings: settings)
        #expect(a.token == b.token)
    }

    @Test("token changes when theme id changes")
    func tokenChangesWithThemeId() {
        let settings = freshSettings()
        let before = TerminalAppearance(settings: settings)
        settings.terminalThemeId = "dracula"
        let after = TerminalAppearance(settings: settings)
        #expect(before.token != after.token)
    }

    @Test("token changes when font name changes")
    func tokenChangesWithFontName() {
        let settings = freshSettings()
        let before = TerminalAppearance(settings: settings)
        settings.terminalFontName = "Menlo-Regular"
        let after = TerminalAppearance(settings: settings)
        #expect(before.token != after.token)
    }

    @Test("token changes when font size changes")
    func tokenChangesWithFontSize() {
        let settings = freshSettings()
        let before = TerminalAppearance(settings: settings)
        settings.terminalFontSize = 18
        let after = TerminalAppearance(settings: settings)
        #expect(before.token != after.token)
    }

    @Test("token changes when cursor block flag changes")
    func tokenChangesWithCursorBlock() {
        let settings = freshSettings()
        let before = TerminalAppearance(settings: settings)
        settings.terminalCursorBlock = false
        let after = TerminalAppearance(settings: settings)
        #expect(before.token != after.token)
    }

    @Test("token changes when cursor blinks flag changes")
    func tokenChangesWithCursorBlinks() {
        let settings = freshSettings()
        let before = TerminalAppearance(settings: settings)
        settings.terminalCursorBlinks = true
        let after = TerminalAppearance(settings: settings)
        #expect(before.token != after.token)
    }

    @Test("token changes when copyOnSelect flag changes")
    func tokenChangesWithCopyOnSelect() {
        let settings = freshSettings()
        let before = TerminalAppearance(settings: settings)
        settings.terminalCopyOnSelect = false
        let after = TerminalAppearance(settings: settings)
        #expect(before.token != after.token)
    }

    @Test("token changes when hideMouseWhileTyping flag changes")
    func tokenChangesWithHideMouseWhileTyping() {
        let settings = freshSettings()
        let before = TerminalAppearance(settings: settings)
        settings.terminalHideMouseWhileTyping = false
        let after = TerminalAppearance(settings: settings)
        #expect(before.token != after.token)
    }

    @Test(".fallback matches the defaults-equivalent appearance")
    func fallbackMatchesDefaultSettings() {
        let fallback = TerminalAppearance.fallback
        let fromDefaultSettings = TerminalAppearance(settings: freshSettings())
        #expect(fallback == fromDefaultSettings)
    }
}
