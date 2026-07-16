//
//  TerminalTheme.swift
//  Devtail
//
//  Built-in terminal color themes. Colors are stored as 8-bit RGB components;
//  conversion to SwiftTerm's 16-bit color space happens in the appearance
//  applier (Task 2), not here.
//

import Foundation

/// An 8-bit RGB color, independent of any specific rendering framework.
struct ThemeColor: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    /// Builds a color from a 24-bit hex value, e.g. `0x1e1e2e`.
    init(hex: UInt32) {
        self.red = UInt8((hex >> 16) & 0xFF)
        self.green = UInt8((hex >> 8) & 0xFF)
        self.blue = UInt8(hex & 0xFF)
    }
}

/// A named terminal color theme: background/foreground/cursor/selection plus
/// the 16-color ANSI palette.
struct TerminalTheme {
    let id: String
    let name: String
    let ansi: [ThemeColor]
    let background: ThemeColor
    let foreground: ThemeColor
    let cursor: ThemeColor
    let selection: ThemeColor

    /// The 5 built-in themes, in display order.
    static let builtIn: [TerminalTheme] = [
        .catppuccinMocha,
        .catppuccinLatte,
        .dracula,
        .solarizedDark,
        .oneDark
    ]

    /// Looks up a built-in theme by id, falling back to Catppuccin Mocha
    /// (the app default) when the id is unknown.
    static func theme(id: String) -> TerminalTheme {
        builtIn.first { $0.id == id } ?? .catppuccinMocha
    }

    // MARK: - Catppuccin Mocha (default)

    static let catppuccinMocha = TerminalTheme(
        id: "catppuccin-mocha",
        name: "Catppuccin Mocha",
        ansi: [
            ThemeColor(hex: 0x45475a), // black
            ThemeColor(hex: 0xf38ba8), // red
            ThemeColor(hex: 0xa6e3a1), // green
            ThemeColor(hex: 0xf9e2af), // yellow
            ThemeColor(hex: 0x89b4fa), // blue
            ThemeColor(hex: 0xf5c2e7), // magenta
            ThemeColor(hex: 0x94e2d5), // cyan
            ThemeColor(hex: 0xbac2de), // white
            ThemeColor(hex: 0x585b70), // bright black
            ThemeColor(hex: 0xf38ba8), // bright red
            ThemeColor(hex: 0xa6e3a1), // bright green
            ThemeColor(hex: 0xf9e2af), // bright yellow
            ThemeColor(hex: 0x89b4fa), // bright blue
            ThemeColor(hex: 0xf5c2e7), // bright magenta
            ThemeColor(hex: 0x94e2d5), // bright cyan
            ThemeColor(hex: 0xa6adc8)  // bright white
        ],
        background: ThemeColor(hex: 0x1e1e2e),
        foreground: ThemeColor(hex: 0xcdd6f4),
        cursor: ThemeColor(hex: 0xf5e0dc),
        selection: ThemeColor(hex: 0x585b70)
    )

    // MARK: - Catppuccin Latte

    static let catppuccinLatte = TerminalTheme(
        id: "catppuccin-latte",
        name: "Catppuccin Latte",
        ansi: [
            ThemeColor(hex: 0x5c5f77), // black
            ThemeColor(hex: 0xd20f39), // red
            ThemeColor(hex: 0x40a02b), // green
            ThemeColor(hex: 0xdf8e1d), // yellow
            ThemeColor(hex: 0x1e66f5), // blue
            ThemeColor(hex: 0xea76cb), // magenta
            ThemeColor(hex: 0x179299), // cyan
            ThemeColor(hex: 0xacb0be), // white
            ThemeColor(hex: 0x6c6f85), // bright black
            ThemeColor(hex: 0xd20f39), // bright red
            ThemeColor(hex: 0x40a02b), // bright green
            ThemeColor(hex: 0xdf8e1d), // bright yellow
            ThemeColor(hex: 0x1e66f5), // bright blue
            ThemeColor(hex: 0xea76cb), // bright magenta
            ThemeColor(hex: 0x179299), // bright cyan
            ThemeColor(hex: 0xbcc0cc)  // bright white
        ],
        background: ThemeColor(hex: 0xeff1f5),
        foreground: ThemeColor(hex: 0x4c4f69),
        cursor: ThemeColor(hex: 0xdc8a78),
        selection: ThemeColor(hex: 0xacb0be)
    )

    // MARK: - Dracula

    static let dracula = TerminalTheme(
        id: "dracula",
        name: "Dracula",
        ansi: [
            ThemeColor(hex: 0x21222c), // black
            ThemeColor(hex: 0xff5555), // red
            ThemeColor(hex: 0x50fa7b), // green
            ThemeColor(hex: 0xf1fa8c), // yellow
            ThemeColor(hex: 0xbd93f9), // blue
            ThemeColor(hex: 0xff79c6), // magenta
            ThemeColor(hex: 0x8be9fd), // cyan
            ThemeColor(hex: 0xf8f8f2), // white
            ThemeColor(hex: 0x6272a4), // bright black
            ThemeColor(hex: 0xff6e6e), // bright red
            ThemeColor(hex: 0x69ff94), // bright green
            ThemeColor(hex: 0xffffa5), // bright yellow
            ThemeColor(hex: 0xd6acff), // bright blue
            ThemeColor(hex: 0xff92df), // bright magenta
            ThemeColor(hex: 0xa4ffff), // bright cyan
            ThemeColor(hex: 0xffffff)  // bright white
        ],
        background: ThemeColor(hex: 0x282a36),
        foreground: ThemeColor(hex: 0xf8f8f2),
        cursor: ThemeColor(hex: 0xf8f8f2),
        selection: ThemeColor(hex: 0x44475a)
    )

    // MARK: - Solarized Dark

    static let solarizedDark = TerminalTheme(
        id: "solarized-dark",
        name: "Solarized Dark",
        ansi: [
            ThemeColor(hex: 0x073642), // black (base02)
            ThemeColor(hex: 0xdc322f), // red
            ThemeColor(hex: 0x859900), // green
            ThemeColor(hex: 0xb58900), // yellow
            ThemeColor(hex: 0x268bd2), // blue
            ThemeColor(hex: 0xd33682), // magenta
            ThemeColor(hex: 0x2aa198), // cyan
            ThemeColor(hex: 0xeee8d5), // white (base2)
            ThemeColor(hex: 0x002b36), // bright black (base03)
            ThemeColor(hex: 0xcb4b16), // bright red (orange)
            ThemeColor(hex: 0x586e75), // bright green (base01)
            ThemeColor(hex: 0x657b83), // bright yellow (base00)
            ThemeColor(hex: 0x839496), // bright blue (base0)
            ThemeColor(hex: 0x6c71c4), // bright magenta (violet)
            ThemeColor(hex: 0x93a1a1), // bright cyan (base1)
            ThemeColor(hex: 0xfdf6e3)  // bright white (base3)
        ],
        background: ThemeColor(hex: 0x002b36),
        foreground: ThemeColor(hex: 0x839496),
        cursor: ThemeColor(hex: 0x839496),
        selection: ThemeColor(hex: 0x073642)
    )

    // MARK: - One Dark (Atom)

    static let oneDark = TerminalTheme(
        id: "one-dark",
        name: "One Dark",
        ansi: [
            ThemeColor(hex: 0x282c34), // black
            ThemeColor(hex: 0xe06c75), // red
            ThemeColor(hex: 0x98c379), // green
            ThemeColor(hex: 0xe5c07b), // yellow
            ThemeColor(hex: 0x61afef), // blue
            ThemeColor(hex: 0xc678dd), // magenta
            ThemeColor(hex: 0x56b6c2), // cyan
            ThemeColor(hex: 0xabb2bf), // white
            ThemeColor(hex: 0x5c6370), // bright black
            ThemeColor(hex: 0xe06c75), // bright red
            ThemeColor(hex: 0x98c379), // bright green
            ThemeColor(hex: 0xe5c07b), // bright yellow
            ThemeColor(hex: 0x61afef), // bright blue
            ThemeColor(hex: 0xc678dd), // bright magenta
            ThemeColor(hex: 0x56b6c2), // bright cyan
            ThemeColor(hex: 0xffffff)  // bright white
        ],
        background: ThemeColor(hex: 0x282c34),
        foreground: ThemeColor(hex: 0xabb2bf),
        cursor: ThemeColor(hex: 0x528bff),
        selection: ThemeColor(hex: 0x3e4451)
    )
}
