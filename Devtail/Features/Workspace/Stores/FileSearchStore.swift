//
//  FileSearchStore.swift
//  Devtail
//
//  Observable state for file-name search in the files side panel. Mirrors
//  the gitStatus/claudeInfo seam on WorkspaceSession: each query change
//  cancels the in-flight walk task and starts a new one after a debounce.
//  The debounce interval is injectable so tests run without real sleeps.
//

import Foundation

@Observable
final class FileSearchStore {
    /// Keystroke debounce before a walk starts — long enough to coalesce a
    /// typing burst, short enough to feel immediate.
    nonisolated static let debounceInterval: Duration = .milliseconds(250)

    let root: URL
    private let walker: FileSearching
    private let matcher = FileNameMatcher()
    private let debounce: Duration

    /// Raw search-field text. Every change cancels the in-flight walk and,
    /// for a non-empty query, schedules a new one after the debounce.
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            queryChanged()
        }
    }
    private(set) var results: [FileSearchResult] = []
    /// True from the moment a searchable query is set until its walk
    /// finishes (or the query is cleared) — gates the panel's empty state so
    /// "no matches" never flashes while a walk is still pending.
    private(set) var isSearching = false
    /// Incremented by `requestFocus()` (Cmd+P) and reset via
    /// `clearFocusRequest()` once FileTreeColumn consumes it — reset rather
    /// than left growing so a remounted panel doesn't re-steal focus from a
    /// long-consumed request.
    private(set) var searchFocusRequest = 0

    /// Whether the query is searchable (non-empty after trimming) — the
    /// panel swaps the tree for the result list on this.
    var isActive: Bool { matcher.normalizedQuery(from: query) != nil }

    /// In-flight debounce+walk task, exposed read-only so tests can await
    /// completion instead of sleeping.
    @ObservationIgnored private(set) var searchTask: Task<Void, Never>?

    init(root: URL, walker: FileSearching, debounce: Duration = FileSearchStore.debounceInterval) {
        self.root = root
        self.walker = walker
        self.debounce = debounce
    }

    func requestFocus() {
        searchFocusRequest += 1
    }

    func clearFocusRequest() {
        searchFocusRequest = 0
    }

    /// The task captures the query it was started for — a stale walk must
    /// never publish under a newer query. It checks cancellation after the
    /// sleep (superseded during debounce) and after the walk (superseded
    /// while walking; the walker also bails cooperatively mid-recursion).
    private func queryChanged() {
        searchTask?.cancel()
        searchTask = nil
        guard matcher.normalizedQuery(from: query) != nil else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        let query = query
        searchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            let found = walker.search(root: root, query: query)
            guard !Task.isCancelled else { return }
            results = found
            isSearching = false
        }
    }
}
