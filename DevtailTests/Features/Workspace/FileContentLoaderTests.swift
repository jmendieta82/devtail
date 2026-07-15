import Foundation
import Testing
@testable import Devtail

struct FileContentLoaderTests {
    private func makeFile(_ name: String, _ data: Data) throws -> (URL, () -> Void) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-loader-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try data.write(to: url)
        return (url, { try? FileManager.default.removeItem(at: folder) })
    }

    @Test func smallSwiftFileIsHighlightableText() throws {
        let (url, cleanup) = try makeFile("a.swift", Data("let x = 1\n".utf8))
        defer { cleanup() }
        #expect(FileContentLoader.load(path: url.path) == .text("let x = 1\n", language: "swift", highlightable: true))
    }

    @Test func nulByteMeansBinary() throws {
        let (url, cleanup) = try makeFile("blob.bin", Data([0x41, 0x00, 0x42]))
        defer { cleanup() }
        #expect(FileContentLoader.load(path: url.path) == .binary)
    }

    @Test func overHighlightLimitIsPlainText() throws {
        let big = String(repeating: "a", count: FileContentLoader.highlightByteLimit + 1)
        let (url, cleanup) = try makeFile("big.txt", Data(big.utf8))
        defer { cleanup() }
        if case .text(_, _, let highlightable) = FileContentLoader.load(path: url.path) {
            #expect(highlightable == false)
        } else { Issue.record("expected .text") }
    }

    @Test func overPlainLimitIsTooLarge() throws {
        let (url, cleanup) = try makeFile("huge.txt", Data(count: FileContentLoader.plainByteLimit + 1))
        defer { cleanup() }
        // Data(count:) is all zeros → would be detected as binary; use 'a' bytes instead
        try Data(String(repeating: "a", count: FileContentLoader.plainByteLimit + 1).utf8).write(to: url)
        if case .tooLarge = FileContentLoader.load(path: url.path) {} else { Issue.record("expected .tooLarge") }
    }

    @Test func missingFileIsUnreadable() {
        if case .unreadable = FileContentLoader.load(path: "/nonexistent/nope.txt") {} else { Issue.record("expected .unreadable") }
    }

    @Test func manyLinesDisableHighlight() throws {
        let lines = String(repeating: "x\n", count: FileContentLoader.highlightLineLimit + 1)
        let (url, cleanup) = try makeFile("lines.txt", Data(lines.utf8))
        defer { cleanup() }
        if case .text(_, _, let highlightable) = FileContentLoader.load(path: url.path) {
            #expect(highlightable == false)
        } else { Issue.record("expected .text") }
    }
}
