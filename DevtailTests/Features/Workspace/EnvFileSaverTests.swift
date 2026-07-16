//
//  EnvFileSaverTests.swift
//  DevtailTests
//
//  TDD for EnvFileSaver: atomic writes plus on-disk modification-date
//  conflict detection, using real temp dirs (same pattern as
//  FileContentLoaderTests).
//

import Foundation
import Testing
@testable import Devtail

struct EnvFileSaverTests {
    private func makeFile(_ name: String, _ contents: String) throws -> (URL, () -> Void) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-envsaver-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return (url, { try? FileManager.default.removeItem(at: folder) })
    }

    private func modificationDate(of url: URL) throws -> Date {
        try (url.resourceValues(forKeys: [.contentModificationDateKey])).contentModificationDate!
    }

    // MARK: - modificationDate(at:)

    @Test func modificationDateReadsExistingFile() throws {
        let (url, cleanup) = try makeFile(".env", "A=1\n")
        defer { cleanup() }
        #expect(EnvFileSaver.modificationDate(at: url.path) != nil)
    }

    @Test func modificationDateIsNilForMissingFile() {
        #expect(EnvFileSaver.modificationDate(at: "/nonexistent/.env") == nil)
    }

    // MARK: - conflict detection

    @Test func noConflictWhenRecordedDateMatchesDisk() throws {
        let (url, cleanup) = try makeFile(".env", "A=1\n")
        defer { cleanup() }
        let recorded = try modificationDate(of: url)
        #expect(EnvFileSaver.hasConflict(path: url.path, recordedModificationDate: recorded) == false)
    }

    @Test func conflictWhenDiskDateIsNewer() throws {
        let (url, cleanup) = try makeFile(".env", "A=1\n")
        defer { cleanup() }
        let recorded = try modificationDate(of: url)
        // Simulate an external edit after we loaded the file.
        try Data("A=2\n".utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: recorded.addingTimeInterval(5)],
            ofItemAtPath: url.path
        )
        #expect(EnvFileSaver.hasConflict(path: url.path, recordedModificationDate: recorded) == true)
    }

    @Test func conflictWhenFileDisappeared() throws {
        let (url, cleanup) = try makeFile(".env", "A=1\n")
        let recorded = try modificationDate(of: url)
        cleanup()
        #expect(EnvFileSaver.hasConflict(path: url.path, recordedModificationDate: recorded) == true)
    }

    // MARK: - save(text:to:)

    @Test func saveWritesTextAtomically() throws {
        let (url, cleanup) = try makeFile(".env", "A=1\n")
        defer { cleanup() }
        try EnvFileSaver.save(text: "A=2\nB=3\n", to: url.path)
        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(written == "A=2\nB=3\n")
    }

    @Test func saveUpdatesModificationDate() throws {
        let (url, cleanup) = try makeFile(".env", "A=1\n")
        defer { cleanup() }
        let before = try modificationDate(of: url)
        // Ensure a measurable time delta on filesystems with coarse mtime resolution.
        try FileManager.default.setAttributes(
            [.modificationDate: before.addingTimeInterval(-5)],
            ofItemAtPath: url.path
        )
        try EnvFileSaver.save(text: "A=2\n", to: url.path)
        let after = EnvFileSaver.modificationDate(at: url.path)
        #expect(after != nil)
        #expect(after! > before.addingTimeInterval(-5))
    }

    @Test func saveToMissingDirectoryThrows() throws {
        let missingPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-envsaver-missing-\(UUID().uuidString)")
            .appendingPathComponent(".env").path
        #expect(throws: (any Error).self) {
            try EnvFileSaver.save(text: "A=1\n", to: missingPath)
        }
    }
}
