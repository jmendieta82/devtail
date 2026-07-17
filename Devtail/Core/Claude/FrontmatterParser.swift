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
