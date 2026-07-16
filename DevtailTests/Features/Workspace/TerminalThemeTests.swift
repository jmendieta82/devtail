//
//  TerminalThemeTests.swift
//  DevtailTests
//

import Testing
@testable import Devtail

@Suite("TerminalTheme")
struct TerminalThemeTests {

    @Test("builtIn contains exactly the 5 expected theme ids")
    func builtInContainsExpectedIds() {
        let ids = Set(TerminalTheme.builtIn.map(\.id))
        #expect(ids == ["catppuccin-mocha", "catppuccin-latte", "dracula", "solarized-dark", "one-dark"])
    }

    @Test("every built-in theme has exactly 16 ANSI colors")
    func everyThemeHas16AnsiColors() {
        for theme in TerminalTheme.builtIn {
            #expect(theme.ansi.count == 16, "\(theme.id) should have 16 ANSI colors")
        }
    }

    @Test("theme(id:) returns Mocha as fallback for unknown id")
    func unknownIdFallsBackToMocha() {
        let theme = TerminalTheme.theme(id: "unknown")
        #expect(theme.id == "catppuccin-mocha")
    }

    @Test("theme(id:) returns Dracula with name 'Dracula'")
    func draculaHasExpectedName() {
        let theme = TerminalTheme.theme(id: "dracula")
        #expect(theme.name == "Dracula")
    }

    @Test("Catppuccin Mocha matches canonical published values")
    func mochaMatchesCanonicalValues() {
        let mocha = TerminalTheme.theme(id: "catppuccin-mocha")

        #expect(mocha.background == ThemeColor(hex: 0x1e1e2e))
        #expect(mocha.foreground == ThemeColor(hex: 0xcdd6f4))
        #expect(mocha.cursor == ThemeColor(hex: 0xf5e0dc))
        #expect(mocha.selection == ThemeColor(hex: 0x585b70))

        #expect(mocha.ansi[1] == ThemeColor(hex: 0xf38ba8))

        let expectedAnsi: [UInt32] = [
            0x45475a, 0xf38ba8, 0xa6e3a1, 0xf9e2af,
            0x89b4fa, 0xf5c2e7, 0x94e2d5, 0xbac2de,
            0x585b70, 0xf38ba8, 0xa6e3a1, 0xf9e2af,
            0x89b4fa, 0xf5c2e7, 0x94e2d5, 0xa6adc8
        ]
        #expect(mocha.ansi == expectedAnsi.map { ThemeColor(hex: $0) })
    }
}
