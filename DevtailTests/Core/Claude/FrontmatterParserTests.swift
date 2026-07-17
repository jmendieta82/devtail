//
//  FrontmatterParserTests.swift
//  DevtailTests
//
//  TDD for FrontmatterParser: a minimal (not full-YAML) reader for the
//  leading `---\n...\n---` block found in SKILL.md / agent / command
//  markdown files. Only single-line `key: value` pairs are supported —
//  see the design doc's accepted limits.
//

import Testing
@testable import Devtail

struct FrontmatterParserTests {
    @Test func parsesSimpleKeyValuePairs() {
        let markdown = """
        ---
        name: my-skill
        description: Does a thing
        ---
        Body text here.
        """
        let result = FrontmatterParser.parse(markdown)
        #expect(result["name"] == "my-skill")
        #expect(result["description"] == "Does a thing")
    }

    @Test func returnsEmptyDictionaryWhenNoFrontmatter() {
        let markdown = "# Just a heading\nNo frontmatter here."
        let result = FrontmatterParser.parse(markdown)
        #expect(result.isEmpty)
    }

    @Test func stripsSurroundingQuotes() {
        let markdown = """
        ---
        name: "quoted-name"
        description: 'single quoted'
        ---
        """
        let result = FrontmatterParser.parse(markdown)
        #expect(result["name"] == "quoted-name")
        #expect(result["description"] == "single quoted")
    }

    @Test func missingKeyReturnsNilOnLookup() {
        let markdown = """
        ---
        name: only-name
        ---
        """
        let result = FrontmatterParser.parse(markdown)
        #expect(result["description"] == nil)
    }

    @Test func unterminatedFrontmatterReturnsEmptyDictionary() {
        let markdown = """
        ---
        name: broken
        no closing delimiter
        """
        let result = FrontmatterParser.parse(markdown)
        #expect(result.isEmpty)
    }
}
