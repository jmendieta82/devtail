//
//  FileNameMatcher.swift
//  Devtail
//
//  Pure query normalization + file-name matching for workspace file search.
//  Same normalization as ProjectFilterEngine (locked in tests, do not change
//  without updating them): the query is trimmed and lowercased, then tested
//  as a case-insensitive substring of the file name only — parent
//  directories are deliberately not part of the haystack.
//

import Foundation

nonisolated struct FileNameMatcher {

    /// Trimmed, lowercased query ready for `matches(name:normalizedQuery:)`,
    /// or nil when the raw query is empty or whitespace-only (search
    /// inactive — the files panel shows the tree).
    func normalizedQuery(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.lowercased()
    }

    func matches(name: String, normalizedQuery: String) -> Bool {
        name.lowercased().contains(normalizedQuery)
    }
}
