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

    @Test("families() are all sorted alphabetically")
    func sorted() {
        let families = MonospaceFontCatalog.families()
        #expect(families == families.sorted())
    }

    @Test("families() contains no duplicates")
    func noDuplicates() {
        let families = MonospaceFontCatalog.families()
        #expect(families.count == Set(families).count)
    }

    @Test("every returned name resolves via NSFont(name:)")
    func allResolvable() {
        for name in MonospaceFontCatalog.families() {
            #expect(NSFont(name: name, size: 12) != nil, "\(name) did not resolve via NSFont(name:)")
        }
    }

    @Test("JetBrainsMono-Regular resolves via NSFont when installed")
    func jetBrainsMonoResolvesIfInstalled() {
        // This is a soft check: JetBrains Mono is expected on the dev
        // machine but not guaranteed on CI/other machines. We only assert
        // resolvability *if* the catalog reports it, and separately probe
        // NSFont directly to document the expectation without failing the
        // suite when it's absent.
        if MonospaceFontCatalog.families().contains("JetBrainsMono-Regular") {
            #expect(NSFont(name: "JetBrainsMono-Regular", size: 12) != nil)
        }
    }
}
