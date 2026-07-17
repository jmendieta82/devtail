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

    /// Real-shaped frontmatter matching ~/.claude/skills/sdd-spec/SKILL.md:
    /// a `metadata:` block nested with indented `author`/`version`, plus a
    /// nested `name:` key that must NOT overwrite the top-level `name`.
    @Test func nestedMetadataBlockDoesNotLeakOrOverwriteTopLevelKeys() {
        let markdown = """
        ---
        name: sdd-spec
        description: "Write SDD delta specs with requirements and scenarios."
        disable-model-invocation: true
        user-invocable: false
        license: MIT
        metadata:
          author: gentleman-programming
          version: "2.0"
          name: nested-should-not-win
          delegate_only: true
        ---

        Body text here.
        """
        let result = FrontmatterParser.parse(markdown)

        #expect(result["name"] == "sdd-spec")
        #expect(result["description"] == "Write SDD delta specs with requirements and scenarios.")
        #expect(result["license"] == "MIT")

        // Nested keys under `metadata:` must not leak into the flat result.
        #expect(result["author"] == nil)
        #expect(result["version"] == nil)
        #expect(result["delegate_only"] == nil)

        // The top-level `metadata:` line itself is zero-indented, so it is
        // still parsed as a key — just with an empty value, since it only
        // opens a block rather than carrying one on the same line.
        #expect(result["metadata"] == "")
    }
}
