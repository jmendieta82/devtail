//
//  FrontmatterParser.swift
//  Devtail
//
//  Minimal reader for the leading `---\n...\n---` YAML frontmatter block
//  found in Claude Code SKILL.md / agent / command markdown files. This is
//  NOT a full YAML parser — only single-line `key: value` pairs are
//  supported, which is sufficient for the `name`/`description` fields these
//  files use. Multiline values are truncated to their first line (accepted
//  limit — see the design doc).
//
//  Only zero-indentation lines are treated as top-level keys. Real skill
//  frontmatter (see ~/.claude/skills/*/SKILL.md) commonly has a nested
//  `metadata:` block indented with `author:`/`version:` etc. underneath —
//  without an indentation check those nested keys would flatten into the
//  result and could silently overwrite top-level `name`/`description` if a
//  nested block happened to reuse those key names.
//

import Foundation

enum FrontmatterParser {
    /// Parses the leading frontmatter block of `markdown`. Returns an empty
    /// dictionary when there is no frontmatter, or the closing `---`
    /// delimiter is missing.
    static func parse(_ markdown: String) -> [String: String] {
        let lines = markdown.components(separatedBy: "\n")
        guard let first = lines.first, first.trimmingCharacters(in: .whitespaces) == "---" else {
            return [:]
        }
        guard let closingIndex = lines.dropFirst().firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "---"
        }) else {
            return [:]
        }

        var result: [String: String] = [:]
        for line in lines[1..<closingIndex] {
            // Skip indented lines: they belong to a nested block (e.g.
            // `metadata:\n  author: x`), not a top-level key.
            guard let firstChar = line.first, !firstChar.isWhitespace else { continue }
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colonIndex].trimmingCharacters(in: .whitespaces)
            var value = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
            value = stripSurroundingQuotes(value)
            guard !key.isEmpty else { continue }
            result[key] = value
        }
        return result
    }

    private static func stripSurroundingQuotes(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        let pairs: [(Character, Character)] = [("\"", "\""), ("'", "'")]
        for (open, close) in pairs {
            if value.first == open && value.last == close {
                return String(value.dropFirst().dropLast())
            }
        }
        return value
    }
}
