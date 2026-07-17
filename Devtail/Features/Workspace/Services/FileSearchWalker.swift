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
import os.log

nonisolated struct FileSearchResult: Identifiable, Hashable, Sendable {
    let name: String
    /// Parent directory relative to the search root; "" for root-level files.
    let relativeDirectory: String
    /// Absolute path — feeds `WorkspaceSession.openFile(at:)` directly.
    let path: String

    var id: String { path }
}

/// Seam for FileSearchStore: `FileSearchWalker` in production, a spy in
/// tests. Async and Sendable — mirrors `GitStatusReading`/`ClaudeIntrospecting`
/// so the store can await the walk without blocking the main actor.
nonisolated protocol FileSearching: Sendable {
    func search(root: URL, query: String) async -> [FileSearchResult]
}

nonisolated struct FileSearchWalker: FileSearching {
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
    ///
    /// `@concurrent`: the recursive walk is blocking disk I/O, so it must
    /// run on the concurrent executor — never on the caller's actor. The
    /// results array stays local to the walk and crosses back to the
    /// awaiting store only as the returned value. Deliberately NOT
    /// GitStatusReader's DispatchQueue.global + continuation pattern: that
    /// would sever the structured task context, so `Task.isCancelled` in
    /// `walk` would never observe the store's cooperative cancel.
    @concurrent func search(root: URL, query: String) async -> [FileSearchResult] {
        guard let needle = matcher.normalizedQuery(from: query) else { return [] }
        var results: [FileSearchResult] = []
        walk(directory: root, relativeDirectory: "", depth: 0, needle: needle, into: &results)
        return results
    }

    /// `depth` is the depth of the entries listed here (root entries are 0),
    /// matching `FileTreeNode.depth` so the maxDepth guard bounds search and
    /// tree identically. The `Task.isCancelled` check makes a superseded
    /// store walk bail mid-recursion instead of finishing a stale query —
    /// the cancel arrives from the main actor while the walk runs on the
    /// concurrent executor inside the same task.
    private func walk(directory: URL, relativeDirectory: String, depth: Int,
                      needle: String, into results: inout [FileSearchResult]) {
        let entries: [DirectoryEntry]
        do {
            entries = try lister.list(directory)
        } catch {
            // One line per skipped directory — never per file (hot loop).
            Log.search.debug("Search skipped unreadable directory \(directory.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }
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
