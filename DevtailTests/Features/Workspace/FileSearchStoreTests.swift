import Foundation
import Testing
@testable import Devtail

@MainActor
final class SpyFileSearcher: FileSearching {
    var resultsByQuery: [String: [FileSearchResult]] = [:]
    private(set) var searchedQueries: [String] = []

    func search(root: URL, query: String) -> [FileSearchResult] {
        searchedQueries.append(query)
        return resultsByQuery[query] ?? []
    }
}

@MainActor
struct FileSearchStoreTests {
    private func result(_ path: String) -> FileSearchResult {
        FileSearchResult(name: (path as NSString).lastPathComponent, relativeDirectory: "", path: path)
    }
    private func makeStore(spy: SpyFileSearcher) -> FileSearchStore {
        FileSearchStore(root: URL(fileURLWithPath: "/root"), walker: spy, debounce: .zero)
    }

    @Test func queryDrivesResults() async {
        let spy = SpyFileSearcher()
        spy.resultsByQuery["main"] = [result("/root/main.swift")]
        let store = makeStore(spy: spy)

        store.query = "main"
        #expect(store.isSearching)
        #expect(store.isActive)

        await store.searchTask?.value

        #expect(store.results.map(\.path) == ["/root/main.swift"])
        #expect(!store.isSearching)
    }

    @Test func clearingQueryRestoresIdle() async {
        let spy = SpyFileSearcher()
        spy.resultsByQuery["main"] = [result("/root/main.swift")]
        let store = makeStore(spy: spy)
        store.query = "main"
        await store.searchTask?.value
        #expect(!store.results.isEmpty)

        store.query = ""

        #expect(store.results.isEmpty)
        #expect(!store.isSearching)
        #expect(!store.isActive)
        #expect(store.searchTask == nil)
    }

    @Test func whitespaceOnlyQueryNeverSearches() {
        let spy = SpyFileSearcher()
        let store = makeStore(spy: spy)

        store.query = "   "

        #expect(store.searchTask == nil)
        #expect(!store.isSearching)
        #expect(!store.isActive)
        #expect(spy.searchedQueries.isEmpty)
    }

    @Test func rapidQueryChangeCancelsInFlightWalk() async {
        let spy = SpyFileSearcher()
        spy.resultsByQuery["ma"] = [result("/root/main.swift")]
        let store = makeStore(spy: spy)

        store.query = "m"
        store.query = "ma"
        await store.searchTask?.value

        // The first walk was cancelled during its debounce — the walker
        // only ever ran for the final query.
        #expect(spy.searchedQueries == ["ma"])
        #expect(store.results.map(\.path) == ["/root/main.swift"])
        #expect(!store.isSearching)
    }

    @Test func reassigningSameQueryDoesNotRestartSearch() async {
        let spy = SpyFileSearcher()
        let store = makeStore(spy: spy)

        store.query = "main"
        await store.searchTask?.value
        store.query = "main"

        #expect(spy.searchedQueries == ["main"])
    }

    @Test func focusRequestCounterIncrementsAndClears() {
        let store = makeStore(spy: SpyFileSearcher())
        #expect(store.searchFocusRequest == 0)

        store.requestFocus()
        #expect(store.searchFocusRequest == 1)
        store.requestFocus()
        #expect(store.searchFocusRequest == 2)

        store.clearFocusRequest()
        #expect(store.searchFocusRequest == 0)
    }
}
