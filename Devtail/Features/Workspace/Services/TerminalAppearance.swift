//
//  TerminalAppearance.swift
//  Devtail
//
//  Resolves AppSettings' terminal fields into a concrete, applyable
//  appearance: font, 16-color ANSI palette, native colors, cursor style,
//  and the two DevtailTerminalView behavior flags. Value type so it can be
//  diffed cheaply (via `token`) to guard against redundant re-application.
//

import AppKit
import SwiftTerm

struct TerminalAppearance: Equatable {
    let themeId: String
    let fontName: String
    let fontSize: Double
    let cursorBlock: Bool
    let cursorBlinks: Bool
    let copyOnSelect: Bool
    let hideMouseWhileTyping: Bool

    init(settings: AppSettings) {
        self.themeId = settings.terminalThemeId
        self.fontName = settings.terminalFontName
        self.fontSize = settings.terminalFontSize
        self.cursorBlock = settings.terminalCursorBlock
        self.cursorBlinks = settings.terminalCursorBlinks
        self.copyOnSelect = settings.terminalCopyOnSelect
        self.hideMouseWhileTyping = settings.terminalHideMouseWhileTyping
    }

    private init(
        themeId: String, fontName: String, fontSize: Double,
        cursorBlock: Bool, cursorBlinks: Bool,
        copyOnSelect: Bool, hideMouseWhileTyping: Bool
    ) {
        self.themeId = themeId
        self.fontName = fontName
        self.fontSize = fontSize
        self.cursorBlock = cursorBlock
        self.cursorBlinks = cursorBlinks
        self.copyOnSelect = copyOnSelect
        self.hideMouseWhileTyping = hideMouseWhileTyping
    }

    /// Defaults-equivalent appearance (mirrors `AppSettings`'s own defaults —
    /// Javier's Ghostty config) — used as the `SwiftTermEngine.appearanceProvider`
    /// default so call sites that don't wire a real provider (tests, mocks)
    /// still compile and produce a sane, non-empty appearance.
    static let fallback = TerminalAppearance(
        themeId: "catppuccin-mocha",
        fontName: "JetBrainsMono-Regular",
        fontSize: 14,
        cursorBlock: true,
        cursorBlinks: false,
        copyOnSelect: true,
        hideMouseWhileTyping: true
    )

    /// Identity string for the idempotency guard (e.g. `TerminalHostView`'s
    /// live re-apply in Task 3): equal settings always produce equal tokens,
    /// any field change always changes it.
    var token: String {
        "\(themeId)|\(fontName)|\(fontSize)|\(cursorBlock)|\(cursorBlinks)|\(copyOnSelect)|\(hideMouseWhileTyping)"
    }

    /// Resolves a font by PostScript/family name, falling back to the
    /// system's monospaced font at the same size and weight when the name
    /// doesn't resolve (e.g. JetBrains Mono not installed on this machine).
    static func resolveFont(name: String, size: Double) -> NSFont {
        NSFont(name: name, size: CGFloat(size)) ?? .monospacedSystemFont(ofSize: CGFloat(size), weight: .regular)
    }

    /// Applies this appearance to a live SwiftTerm view: font, 16-color ANSI
    /// palette, native colors, cursor style, and — if the view is a
    /// `DevtailTerminalView` — the copy-on-select / mouse-hide flags.
    func apply(to view: TerminalView) {
        let theme = TerminalTheme.theme(id: themeId)

        view.font = Self.resolveFont(name: fontName, size: fontSize)
        view.installColors(theme.ansi.map(Self.swiftTermColor))
        view.nativeForegroundColor = Self.nsColor(theme.foreground)
        view.nativeBackgroundColor = Self.nsColor(theme.background)
        view.caretColor = Self.nsColor(theme.cursor)
        view.selectedTextBackgroundColor = Self.nsColor(theme.selection)

        let style: CursorStyle
        switch (cursorBlock, cursorBlinks) {
        case (true, true): style = .blinkBlock
        case (true, false): style = .steadyBlock
        case (false, true): style = .blinkBar
        case (false, false): style = .steadyBar
        }
        view.getTerminal().setCursorStyle(style)

        if let devtailView = view as? DevtailTerminalView {
            devtailView.copyOnSelect = copyOnSelect
            devtailView.hideMouseWhileTyping = hideMouseWhileTyping
        }
    }

    /// SwiftTerm's `installColors` requires exactly 16 colors with 16-bit
    /// (0-65535) components — 8-bit components are widened by `* 257`
    /// (0...255 * 257 == 0...65535, an exact bit-replication scale).
    private static func swiftTermColor(_ color: ThemeColor) -> SwiftTerm.Color {
        SwiftTerm.Color(
            red: UInt16(color.red) * 257,
            green: UInt16(color.green) * 257,
            blue: UInt16(color.blue) * 257
        )
    }

    private static func nsColor(_ color: ThemeColor) -> NSColor {
        NSColor(
            red: CGFloat(color.red) / 255,
            green: CGFloat(color.green) / 255,
            blue: CGFloat(color.blue) / 255,
            alpha: 1
        )
    }
}
