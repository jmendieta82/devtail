import Foundation
import Testing
@testable import Devtail

/// Shared with FileSearchWalkerTests, whose walker lists directories off the
/// main actor — hence nonisolated + `@unchecked Sendable` (same pattern as
/// MockGitStatusReader). Tests mutate state before a walk and read it after,
/// never concurrently with one.
nonisolated final class MockDirectoryLister: DirectoryLister, @unchecked Sendable {
    var entriesByPath: [String: [DirectoryEntry]] = [:]
    var errorPaths: Set<String> = []
    private(set) var listedPaths: [String] = []

    func list(_ directory: URL) throws -> [DirectoryEntry] {
        listedPaths.append(directory.path)
        if errorPaths.contains(directory.path) {
            throw NSError(domain: "mock", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
        }
        return entriesByPath[directory.path] ?? []
    }
}

@MainActor
struct FileTreeStoreTests {
    private func dir(_ path: String) -> DirectoryEntry {
        DirectoryEntry(name: (path as NSString).lastPathComponent, url: URL(fileURLWithPath: path), isDirectory: true)
    }
    private func file(_ path: String) -> DirectoryEntry {
        DirectoryEntry(name: (path as NSString).lastPathComponent, url: URL(fileURLWithPath: path), isDirectory: false)
    }

    @Test func loadRootListsOnceAndIsIdempotent() {
        let mock = MockDirectoryLister()
        mock.entriesByPath["/root"] = [file("/root/a.txt")]
        let store = FileTreeStore(root: URL(fileURLWithPath: "/root"), lister: mock)
        store.loadRootIfNeeded()
        store.loadRootIfNeeded()
        #expect(mock.listedPaths == ["/root"])
        #expect(store.rootNodes?.count == 1)
    }

    @Test func reloadRootRelistsAndReflectsNewEntries() {
        let mock = MockDirectoryLister()
        mock.entriesByPath["/root"] = [file("/root/a.txt")]
        let store = FileTreeStore(root: URL(fileURLWithPath: "/root"), lister: mock)
        store.loadRootIfNeeded()
        #expect(store.rootNodes?.count == 1)

        // A file appears on disk; reload must pick it up (loadRootIfNeeded would not).
        mock.entriesByPath["/root"] = [file("/root/a.txt"), file("/root/b.txt")]
        store.reloadRoot()

        #expect(mock.listedPaths == ["/root", "/root"])
        #expect(store.rootNodes?.count == 2)
    }

    @Test func reloadRootClearsPriorError() {
        let mock = MockDirectoryLister()
        mock.errorPaths = ["/root"]
        let store = FileTreeStore(root: URL(fileURLWithPath: "/root"), lister: mock)
        store.loadRootIfNeeded()
        #expect(store.rootError != nil)

        mock.errorPaths = []
        mock.entriesByPath["/root"] = [file("/root/a.txt")]
        store.reloadRoot()

        #expect(store.rootError == nil)
        #expect(store.rootNodes?.count == 1)
    }

    @Test func relativeRootFailsClosed() {
        // Mirrors GitBranchDetectorTests.relativeURLReturnsNil: URL(string: "file:...")
        // yields a genuinely relative path, unlike URL(fileURLWithPath: "") which
        // resolves against CWD.
        let store = FileTreeStore(root: URL(string: "file:some/relative/dir")!, lister: MockDirectoryLister())
        store.loadRootIfNeeded()
        #expect(store.rootNodes == nil)
        #expect(store.rootError != nil)
    }

    @Test func expandLoadsChildrenLazilyOnce() {
        let mock = MockDirectoryLister()
        mock.entriesByPath["/root"] = [dir("/root/sub")]
        mock.entriesByPath["/root/sub"] = [file("/root/sub/x.swift")]
        let store = FileTreeStore(root: URL(fileURLWithPath: "/root"), lister: mock)
        store.loadRootIfNeeded()
        let sub = store.rootNodes![0]
        #expect(sub.children == nil)
        store.toggleExpansion(of: sub)          // expand → loads
        store.toggleExpansion(of: sub)          // collapse
        store.toggleExpansion(of: sub)          // re-expand → does NOT re-list
        #expect(mock.listedPaths.filter { $0 == "/root/sub" }.count == 1)
        #expect(sub.children?.count == 1)
    }

    @Test func expandErrorIsPerNode() {
        let mock = MockDirectoryLister()
        mock.entriesByPath["/root"] = [dir("/root/locked"), file("/root/ok.txt")]
        mock.errorPaths = ["/root/locked"]
        let store = FileTreeStore(root: URL(fileURLWithPath: "/root"), lister: mock)
        store.loadRootIfNeeded()
        let locked = store.rootNodes![0]
        store.toggleExpansion(of: locked)
        #expect(locked.loadError != nil)
        #expect(store.rootError == nil)
    }

    @Test func toggleOnFileIsNoOp() {
        let mock = MockDirectoryLister()
        mock.entriesByPath["/root"] = [file("/root/a.txt")]
        let store = FileTreeStore(root: URL(fileURLWithPath: "/root"), lister: mock)
        store.loadRootIfNeeded()
        let node = store.rootNodes![0]
        store.toggleExpansion(of: node)
        #expect(node.isExpanded == false)
        #expect(mock.listedPaths == ["/root"])
    }

    @Test func depthCapStopsLoading() {
        let mock = MockDirectoryLister()
        let store = FileTreeStore(root: URL(fileURLWithPath: "/root"), lister: mock)
        let deep = FileTreeNode(entry: dir("/root/deep"), depth: FileTreeStore.maxDepth)
        store.toggleExpansion(of: deep)
        #expect(deep.children == nil)
        #expect(deep.loadError != nil)
    }

    @Test func realListerSortsDirsFirstThenNameAndIncludesHidden() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-filetree-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("zdir"), withIntermediateDirectories: true)
        try Data().write(to: folder.appendingPathComponent("Alpha.txt"))
        try Data().write(to: folder.appendingPathComponent(".hidden"))
        let entries = try FileManagerDirectoryLister().list(folder)
        #expect(entries.map(\.name) == ["zdir", ".hidden", "Alpha.txt"])
        #expect(entries[0].isDirectory)
    }
}
