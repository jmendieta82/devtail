//
//  MonospaceFontCatalogTests.swift
//  DevtailTests
//
//  Unit tests for MonospaceFontCatalog. Headless-testable on macOS: the
//  system always ships fixed-pitch fonts (e.g. Menlo, Courier).
//

import Testing
import AppKit
@testable import Devtail

@Suite("MonospaceFontCatalog")
struct MonospaceFontCatalogTests {

    @Test("families() is non-empty on macOS")
    func nonEmpty() {
        #expect(!MonospaceFontCatalog.families().isEmpty)
    }

    @Test("families() are all sorted alphabetically by display name")
    func sorted() {
        let displayNames = MonospaceFontCatalog.families().map(\.displayName)
        #expect(displayNames == displayNames.sorted())
    }

    @Test("families() contains no duplicate face names")
    func noDuplicates() {
        let faceNames = MonospaceFontCatalog.families().map(\.faceName)
        #expect(faceNames.count == Set(faceNames).count)
    }

    @Test("families() has at most one entry per font family")
    func oneEntryPerFamily() {
        let displayNames = MonospaceFontCatalog.families().map(\.displayName)
        #expect(displayNames.count == Set(displayNames).count)
    }

    @Test("every returned face name resolves via NSFont(name:)")
    func allResolvable() {
        for choice in MonospaceFontCatalog.families() {
            #expect(NSFont(name: choice.faceName, size: 12) != nil, "\(choice.faceName) did not resolve via NSFont(name:)")
        }
    }

    @Test("JetBrainsMono-Regular resolves via NSFont when installed")
    func jetBrainsMonoResolvesIfInstalled() {
        // This is a soft check: JetBrains Mono is expected on the dev
        // machine but not guaranteed on CI/other machines. We only assert
        // resolvability *if* the catalog reports it, and separately probe
        // NSFont directly to document the expectation without failing the
        // suite when it's absent.
        if MonospaceFontCatalog.families().contains(where: { $0.faceName == "JetBrainsMono-Regular" }) {
            #expect(NSFont(name: "JetBrainsMono-Regular", size: 12) != nil)
        }
    }
}
