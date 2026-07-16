//
//  MonospaceFontCatalog.swift
//  Devtail
//
//  Enumerates installed fixed-pitch (monospace) fonts for the Terminal
//  settings font picker. Returns one representative face per font family
//  (families like JetBrains Mono ship dozens of weight/style variants that
//  would otherwise clutter the picker). The stored/tagged value is always
//  the face's PostScript name — the same identifier
//  `TerminalAppearance.resolveFont` resolves via `NSFont(name:)`.
//

import AppKit

enum MonospaceFontCatalog {

    /// A single font family's representative face, as shown in the
    /// Terminal settings font picker.
    struct FontChoice: Hashable, Identifiable {
        /// PostScript name of the representative face, e.g.
        /// "JetBrainsMono-Regular". Resolvable via `NSFont(name:)` and is
        /// the value stored in `AppSettings.terminalFontName`.
        let faceName: String

        /// Family display name, e.g. "JetBrains Mono".
        let displayName: String

        var id: String { faceName }
    }

    /// One representative face per installed fixed-pitch font family,
    /// alphabetically sorted by display name and de-duplicated.
    static func families() -> [FontChoice] {
        let fontManager = NSFontManager.shared
        let fixedPitchNames = Set(fontManager.availableFontNames(with: .fixedPitchFontMask) ?? [])
        guard !fixedPitchNames.isEmpty else { return [] }

        var familyNames = Set<String>()
        for name in fixedPitchNames {
            if let familyName = NSFont(name: name, size: 12)?.familyName {
                familyNames.insert(familyName)
            }
        }

        var choices: [FontChoice] = []
        for familyName in familyNames {
            guard let representative = representativeFace(
                ofFamily: familyName,
                fontManager: fontManager,
                fixedPitchNames: fixedPitchNames
            ) else { continue }
            choices.append(FontChoice(faceName: representative, displayName: familyName))
        }

        return choices.sorted { $0.displayName < $1.displayName }
    }

    /// Picks the "Regular"/"Book"/plain member of a font family, preferring
    /// NSFontManager's reported weight 5 / traits 0 member, else the first
    /// member that is itself fixed-pitch.
    private static func representativeFace(
        ofFamily familyName: String,
        fontManager: NSFontManager,
        fixedPitchNames: Set<String>
    ) -> String? {
        guard let members = fontManager.availableMembers(ofFontFamily: familyName) else {
            return nil
        }

        // Each member is [name, styleName, weight, traits].
        for member in members {
            guard let name = member[0] as? String,
                  let weight = member[2] as? Int,
                  let traits = member[3] as? Int,
                  fixedPitchNames.contains(name) else { continue }
            if weight == 5 && traits == 0 {
                return name
            }
        }

        for member in members {
            guard let name = member[0] as? String, fixedPitchNames.contains(name) else { continue }
            return name
        }

        return nil
    }
}
