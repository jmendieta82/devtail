//
//  MarkdownBlockParser.swift
//  Devtail
//
//  Pure parser turning a markdown String into an ordered array of typed
//  blocks, ready for a SwiftUI renderer. Built entirely on Apple's
//  AttributedString(markdown:) with `.full` interpretedSyntax and
//  presentation intents — no custom markdown grammar, no SPM dependency.
//
//  Verified choice: `.full` interpretedSyntax correctly emits distinct runs
//  per block (heading levels, code blocks with verbatim text + language,
//  ordered/unordered list items with ordinals, block quotes, thematic
//  breaks) with document order preserved across `attr.runs`. No fence
//  pre-pass is needed — a standalone script confirmed fenced code blocks
//  keep their body byte-for-byte (including the trailing newline) and their
//  language tag under `presentationIntent.components` as `.codeBlock(language:)`.
//

import Foundation

/// A single rendering unit extracted from a markdown document, in source order.
enum MarkdownBlock: Equatable {
    case heading(level: Int, text: AttributedString)
    case paragraph(AttributedString)
    case codeBlock(language: String?, text: String)
    /// `ordinal` is non-nil for ordered list items (1-based); nil for bullets.
    /// `indent` is the nesting depth (0 = top-level).
    case listItem(ordinal: Int?, indent: Int, text: AttributedString)
    case blockQuote(AttributedString)
    case thematicBreak
}

/// Parses markdown text into flat, typed `MarkdownBlock`s using Apple's
/// AttributedString markdown parser. Pure and unit-testable — no SwiftUI.
enum MarkdownBlockParser {
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        guard !markdown.isEmpty else { return [] }

        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .full

        guard let attributed = try? AttributedString(markdown: markdown, options: options) else {
            return []
        }

        // Group consecutive runs that share the same block identity (e.g. all
        // the inline runs of one paragraph, or one list item) before turning
        // each group into a single MarkdownBlock.
        var groups: [(intent: PresentationIntent?, text: AttributedString)] = []
        for run in attributed.runs {
            let runSlice = AttributedString(attributed[run.range])
            let intent = run.presentationIntent
            if let last = groups.last, last.intent?.identity == intent?.identity {
                groups[groups.count - 1].text += runSlice
            } else {
                groups.append((intent, runSlice))
            }
        }

        var blocks: [MarkdownBlock] = []
        for group in groups {
            append(runText: group.text, intent: group.intent, into: &blocks)
        }
        return blocks
    }

    private static func append(runText: AttributedString, intent: PresentationIntent?, into blocks: inout [MarkdownBlock]) {
        guard let intent else {
            blocks.append(.paragraph(runText))
            return
        }

        let components = intent.components

        if let heading = components.first(where: { if case .header = $0.kind { return true } else { return false } }),
           case .header(let level) = heading.kind {
            blocks.append(.heading(level: level, text: runText))
            return
        }

        if let codeBlock = components.first(where: { if case .codeBlock = $0.kind { return true } else { return false } }),
           case .codeBlock(let language) = codeBlock.kind {
            blocks.append(.codeBlock(language: language, text: String(runText.characters)))
            return
        }

        if components.contains(where: { if case .blockQuote = $0.kind { return true } else { return false } }) {
            blocks.append(.blockQuote(runText))
            return
        }

        if components.contains(where: { if case .thematicBreak = $0.kind { return true } else { return false } }) {
            blocks.append(.thematicBreak)
            return
        }

        let listItemComponent = components.first { if case .listItem = $0.kind { return true } else { return false } }
        if let listItemComponent, case .listItem(let ordinalInList) = listItemComponent.kind {
            let listContainerCount = components.filter {
                if case .orderedList = $0.kind { return true }
                if case .unorderedList = $0.kind { return true }
                return false
            }.count
            let indent = max(0, listContainerCount - 1)
            let isOrdered = components.contains { if case .orderedList = $0.kind { return true } else { return false } }
            blocks.append(.listItem(ordinal: isOrdered ? ordinalInList : nil, indent: indent, text: runText))
            return
        }

        blocks.append(.paragraph(runText))
    }
}

private extension PresentationIntent {
    /// A stable identity for the *innermost* block this intent describes,
    /// used to detect when consecutive runs belong to the same block vs.
    /// a new one. Two intents describe the same block when their component
    /// arrays match by kind description.
    var identity: AnyHashable {
        AnyHashable(components.map { "\($0.kind)" }.joined(separator: "|"))
    }
}
