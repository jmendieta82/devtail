import Foundation
import Testing
@testable import Devtail

@MainActor
struct FileSearchWalkerTests {
    private func dir(_ path: String) -> DirectoryEntry {
        DirectoryEntry(name: (path as NSString).lastPathComponent, url: URL(fileURLWithPath: path), isDirectory: true)
    }
    private func file(_ path: String) -> DirectoryEntry {
        DirectoryEntry(name: (path as NSString).lastPathComponent, url: URL(fileURLWithPath: path), isDirectory: false)
    }
    private func search(_ mock: MockDirectoryLister, query: String) -> [FileSearchResult] {
        FileSearchWalker(lister: mock).search(root: URL(fileURLWithPath: "/root"), query: query)
    }

    @Test func recursesAndBuildsRelativeDirectories() {
        let mock = MockDirectoryLister()
        mock.entriesByPath["/root"] = [dir("/root/src"), file("/root/app.swift")]
        mock.entriesByPath["/root/src"] = [dir("/root/src/views"), file("/root/src/main.swift")]
        mock.entriesByPath["/root/src/views"] = [file("/root/src/views/tree.swift")]

        let results = search(mock, query: "swift")

        #expect(results.map(\.name) == ["tree.swift", "main.swift", "app.swift"])
        #expect(results.map(\.relativeDirectory) == ["src/views", "src", ""])
        #expect(results.map(\.path) == [
            "/root/src/views/tree.swift", "/root/src/main.swift", "/root/app.swift"
        ])
    }

    @Test func queryIsTrimmedAndCaseInsensitive() {
        let mock = MockDirectoryLister()
        mock.entriesByPath["/root"] = [file("/root/README.md"), file("/root/notes.txt")]

        let results = search(mock, query: "  readme ")

        #expect(results.map(\.name) == ["README.md"])
    }

    @Test func emptyQueryReturnsNothingWithoutWalking() {
        let mock = MockDirectoryLister()
        mock.entriesByPath["/root"] = [file("/root/a.txt")]

        #expect(search(mock, query: "").isEmpty)
        #expect(search(mock, query: "   ").isEmpty)
        #expect(mock.listedPaths.isEmpty)
    }

    @Test func skipsGitDirectoriesEntirely() {
        let mock = MockDirectoryLister()
        mock.entriesByPath["/root"] = [dir("/root/.git"), file("/root/gitignore-notes.md")]
        mock.entriesByPath["/root/.git"] = [file("/root/.git/config-git.txt")]

        let results = search(mock, query: "git")

        #expect(results.map(\.name) == ["gitignore-notes.md"])
        #expect(!mock.listedPaths.contains("/root/.git"))
    }

    @Test func directoriesNeverMatchOnlyFilesDo() {
        let mock = MockDirectoryLister()
        mock.entriesByPath["/root"] = [dir("/root/matchdir"), file("/root/other.txt")]
        mock.entriesByPath["/root/matchdir"] = []

        #expect(search(mock, query: "match").isEmpty)
    }

    @Test func respectsMaxDepthLikeTheTree() {
        let mock = MockDirectoryLister()
        var path = "/root"
        for level in 0..<40 {
            let child = "\(path)/d\(level)"
            mock.entriesByPath[path] = [dir(child), file("\(path)/match.txt")]
            path = child
        }
        mock.entriesByPath[path] = [file("\(path)/match.txt")]

        let results = search(mock, query: "match")

        // Root entries are depth 0 and the tree loads children while
        // depth < maxDepth, so files exist at depths 0...maxDepth.
        #expect(results.count == FileTreeStore.maxDepth + 1)
        #expect(!mock.listedPaths.contains { $0.hasSuffix("/d32") })
    }

    @Test func capsResultsAtMaxResults() {
        let mock = MockDirectoryLister()
        mock.entriesByPath["/root"] = (0..<150).map { file("/root/match-\($0).txt") }

        #expect(search(mock, query: "match").count == FileSearchWalker.maxResults)
    }

    @Test func stopsWalkingOnceCapIsReached() {
        let mock = MockDirectoryLister()
        var entries = (0..<FileSearchWalker.maxResults).map { file("/root/match-\($0).txt") }
        entries.append(dir("/root/unvisited"))
        mock.entriesByPath["/root"] = entries
        mock.entriesByPath["/root/unvisited"] = [file("/root/unvisited/match-extra.txt")]

        let results = search(mock, query: "match")

        #expect(results.count == FileSearchWalker.maxResults)
        #expect(mock.listedPaths == ["/root"])
    }

    @Test func listerErrorOnSubdirectoryIsSkippedAndWalkContinues() {
        let mock = MockDirectoryLister()
        mock.entriesByPath["/root"] = [dir("/root/locked"), dir("/root/ok"), file("/root/match.txt")]
        mock.entriesByPath["/root/ok"] = [file("/root/ok/match.swift")]
        mock.errorPaths = ["/root/locked"]

        let results = search(mock, query: "match")

        #expect(results.map(\.name) == ["match.swift", "match.txt"])
    }

    @Test func rootListErrorReturnsEmpty() {
        let mock = MockDirectoryLister()
        mock.errorPaths = ["/root"]

        #expect(search(mock, query: "anything").isEmpty)
    }
}
