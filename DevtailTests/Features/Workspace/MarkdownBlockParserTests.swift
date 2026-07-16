import Foundation
import Testing
@testable import Devtail

struct MarkdownBlockParserTests {
    @Test func emptyStringProducesNoBlocks() {
        let blocks = MarkdownBlockParser.parse("")
        #expect(blocks.isEmpty)
    }

    @Test func headingLevelsAreParsed() {
        let blocks = MarkdownBlockParser.parse("# Title\n## Subtitle\n### Smaller")
        #expect(blocks.count == 3)
        guard case .heading(let level1, let text1) = blocks[0],
              case .heading(let level2, let text2) = blocks[1],
              case .heading(let level3, let text3) = blocks[2] else {
            Issue.record("expected three heading blocks")
            return
        }
        #expect(level1 == 1)
        #expect(String(text1.characters) == "Title")
        #expect(level2 == 2)
        #expect(String(text2.characters) == "Subtitle")
        #expect(level3 == 3)
        #expect(String(text3.characters) == "Smaller")
    }

    @Test func paragraphPreservesBoldAndItalicRuns() {
        let blocks = MarkdownBlockParser.parse("Some **bold** and *italic* text.")
        #expect(blocks.count == 1)
        guard case .paragraph(let text) = blocks[0] else {
            Issue.record("expected a paragraph block")
            return
        }
        #expect(String(text.characters) == "Some bold and italic text.")

        var sawBold = false
        var sawItalic = false
        for run in text.runs {
            let runText = String(text[run.range].characters)
            if runText == "bold" {
                #expect(run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
                sawBold = true
            }
            if runText == "italic" {
                #expect(run.inlinePresentationIntent?.contains(.emphasized) == true)
                sawItalic = true
            }
        }
        #expect(sawBold)
        #expect(sawItalic)
    }

    @Test func fencedCodeBlockCapturedVerbatimWithLanguage() {
        let markdown = "```swift\nlet x = 1\nfunc foo() {}\n```"
        let blocks = MarkdownBlockParser.parse(markdown)
        #expect(blocks.count == 1)
        guard case .codeBlock(let language, let text) = blocks[0] else {
            Issue.record("expected a code block")
            return
        }
        #expect(language == "swift")
        #expect(text == "let x = 1\nfunc foo() {}\n")
    }

    @Test func fencedCodeBlockWithoutLanguageHasNilLanguage() {
        let markdown = "```\nplain text\n```"
        let blocks = MarkdownBlockParser.parse(markdown)
        #expect(blocks.count == 1)
        guard case .codeBlock(let language, let text) = blocks[0] else {
            Issue.record("expected a code block")
            return
        }
        #expect(language == nil)
        #expect(text == "plain text\n")
    }

    @Test func unorderedListItemsHaveBulletMarkers() {
        let blocks = MarkdownBlockParser.parse("- item one\n- item two")
        #expect(blocks.count == 2)
        guard case .listItem(let ordinal1, let indent1, let text1) = blocks[0],
              case .listItem(let ordinal2, let indent2, let text2) = blocks[1] else {
            Issue.record("expected two list items")
            return
        }
        #expect(ordinal1 == nil)
        #expect(indent1 == 0)
        #expect(String(text1.characters) == "item one")
        #expect(ordinal2 == nil)
        #expect(indent2 == 0)
        #expect(String(text2.characters) == "item two")
    }

    @Test func orderedListItemsHaveOrdinals() {
        let blocks = MarkdownBlockParser.parse("1. first\n2. second")
        #expect(blocks.count == 2)
        guard case .listItem(let ordinal1, _, let text1) = blocks[0],
              case .listItem(let ordinal2, _, let text2) = blocks[1] else {
            Issue.record("expected two ordered list items")
            return
        }
        #expect(ordinal1 == 1)
        #expect(String(text1.characters) == "first")
        #expect(ordinal2 == 2)
        #expect(String(text2.characters) == "second")
    }

    @Test func blockQuoteIsParsed() {
        let blocks = MarkdownBlockParser.parse("> a quote")
        #expect(blocks.count == 1)
        guard case .blockQuote(let text) = blocks[0] else {
            Issue.record("expected a block quote")
            return
        }
        #expect(String(text.characters) == "a quote")
    }

    @Test func thematicBreakIsParsed() {
        let blocks = MarkdownBlockParser.parse("Before\n\n---\n\nAfter")
        #expect(blocks.count == 3)
        guard case .paragraph = blocks[0],
              case .thematicBreak = blocks[1],
              case .paragraph = blocks[2] else {
            Issue.record("expected paragraph, thematicBreak, paragraph")
            return
        }
    }

    @Test func mixedDocumentPreservesBlockOrder() {
        let markdown = """
        # Title

        Some **bold** and *italic* text.

        ```swift
        let x = 1
        func foo() {}
        ```

        - item one
        - item two

        1. first
        2. second

        > a quote

        ---

        Paragraph after break.
        """
        let blocks = MarkdownBlockParser.parse(markdown)

        let kinds: [String] = blocks.map { block in
            switch block {
            case .heading: return "heading"
            case .paragraph: return "paragraph"
            case .codeBlock: return "codeBlock"
            case .listItem: return "listItem"
            case .blockQuote: return "blockQuote"
            case .thematicBreak: return "thematicBreak"
            }
        }

        #expect(kinds == [
            "heading",
            "paragraph",
            "codeBlock",
            "listItem",
            "listItem",
            "listItem",
            "listItem",
            "blockQuote",
            "thematicBreak",
            "paragraph",
        ])
    }

    @Test func consecutiveParagraphsStayDistinctBlocks() {
        let blocks = MarkdownBlockParser.parse("First paragraph.\n\nSecond paragraph.")
        guard blocks.count == 2 else {
            Issue.record("expected two blocks, got \(blocks.count): \(blocks)")
            return
        }
        guard case .paragraph(let text1) = blocks[0],
              case .paragraph(let text2) = blocks[1] else {
            Issue.record("expected two paragraph blocks")
            return
        }
        #expect(String(text1.characters) == "First paragraph.")
        #expect(String(text2.characters) == "Second paragraph.")
    }

    @Test func consecutiveFencedCodeBlocksStayDistinctBlocks() {
        let markdown = "```\ncode one\n```\n\n```\ncode two\n```"
        let blocks = MarkdownBlockParser.parse(markdown)
        guard blocks.count == 2 else {
            Issue.record("expected two blocks, got \(blocks.count): \(blocks)")
            return
        }
        guard case .codeBlock(let language1, let text1) = blocks[0],
              case .codeBlock(let language2, let text2) = blocks[1] else {
            Issue.record("expected two code blocks")
            return
        }
        #expect(language1 == nil)
        #expect(text1 == "code one\n")
        #expect(language2 == nil)
        #expect(text2 == "code two\n")
    }

    @Test func consecutiveBlockQuotesStayDistinctBlocks() {
        // Empirically verified: AttributedString(markdown:) with .full syntax
        // does NOT merge adjacent block quotes into one intent — each quote
        // gets its own paragraph/blockQuote component pair with a distinct
        // identity. This test locks that behavior in.
        let blocks = MarkdownBlockParser.parse("> quote one\n\n> quote two")
        guard blocks.count == 2 else {
            Issue.record("expected two blocks, got \(blocks.count): \(blocks)")
            return
        }
        guard case .blockQuote(let text1) = blocks[0],
              case .blockQuote(let text2) = blocks[1] else {
            Issue.record("expected two block quote blocks")
            return
        }
        #expect(String(text1.characters) == "quote one")
        #expect(String(text2.characters) == "quote two")
    }
}
