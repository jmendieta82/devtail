//
//  FileSearchWalker.swift
//  Devtail
//
//  Recursive file-name search over the project root. The file tree can't be
//  filtered in place — unexpanded folders are never loaded into the model —
//  so search walks the disk itself, through the same injected
//  DirectoryLister the tree uses (same filesystem view, fully testable).
//
//  Walk rules: skip `.git` directories entirely, honor the tree's
//  FileTreeStore.maxDepth guard, cap results at maxResults and stop walking
//  once the cap is reached. A directory that fails to list is skipped and
//  the walk continues — one unreadable folder must not blank the results.
//

import Foundation

struct FileSearchResult: Identifiable, Hashable {
    let name: String
    /// Parent directory relative to the search root; "" for root-level files.
    let relativeDirectory: String
    /// Absolute path — feeds `WorkspaceSession.openFile(at:)` directly.
    let path: String

    var id: String { path }
}

/// Seam for FileSearchStore: `FileSearchWalker` in production, a spy in tests.
protocol FileSearching {
    func search(root: URL, query: String) -> [FileSearchResult]
}

struct FileSearchWalker: FileSearching {
    /// Hard cap: the panel shows a "first N" hint and the walk short-circuits.
    static let maxResults = 100

    private let lister: DirectoryLister
    private let matcher = FileNameMatcher()

    init(lister: DirectoryLister) {
        self.lister = lister
    }

    /// Results keep walk order (the production lister sorts dirs-first, then
    /// case-insensitive name) — no ranking, per design. Empty/whitespace
    /// queries return [] without touching the lister.
    func search(root: URL, query: String) -> [FileSearchResult] {
        guard let needle = matcher.normalizedQuery(from: query) else { return [] }
        var results: [FileSearchResult] = []
        walk(directory: root, relativeDirectory: "", depth: 0, needle: needle, into: &results)
        return results
    }

    /// `depth` is the depth of the entries listed here (root entries are 0),
    /// matching `FileTreeNode.depth` so the maxDepth guard bounds search and
    /// tree identically. The `Task.isCancelled` check makes a superseded
    /// store walk bail mid-recursion instead of finishing a stale query.
    private func walk(directory: URL, relativeDirectory: String, depth: Int,
                      needle: String, into results: inout [FileSearchResult]) {
        guard let entries = try? lister.list(directory) else { return }
        for entry in entries {
            guard results.count < Self.maxResults, !Task.isCancelled else { return }
            if entry.isDirectory {
                guard entry.name != ".git", depth < FileTreeStore.maxDepth else { continue }
                let childDirectory = relativeDirectory.isEmpty
                    ? entry.name
                    : "\(relativeDirectory)/\(entry.name)"
                walk(directory: entry.url, relativeDirectory: childDirectory,
                     depth: depth + 1, needle: needle, into: &results)
            } else if matcher.matches(name: entry.name, normalizedQuery: needle) {
                results.append(FileSearchResult(
                    name: entry.name,
                    relativeDirectory: relativeDirectory,
                    path: entry.url.path
                ))
            }
        }
    }
}
