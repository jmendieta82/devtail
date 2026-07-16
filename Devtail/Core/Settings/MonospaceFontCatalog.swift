//
//  MonospaceFontCatalog.swift
//  Devtail
//
//  Enumerates installed fixed-pitch (monospace) fonts for the Terminal
//  settings font picker. Returns PostScript names — the same identifier
//  `TerminalAppearance.resolveFont` resolves via `NSFont(name:)`.
//

import AppKit

enum MonospaceFontCatalog {

    /// All installed fixed-pitch font PostScript names, alphabetically
    /// sorted and de-duplicated.
    static func families() -> [String] {
        let names = NSFontManager.shared.availableFontNames(with: .fixedPitchFontMask) ?? []
        return Array(Set(names)).sorted()
    }
}
