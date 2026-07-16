//
//  WorkspaceSessionDirtyFilesTests.swift
//  DevtailTests
//
//  TDD for WorkspaceSession's env-draft store: the single source of truth
//  for open env files' in-progress edits. Dirty state derives from the
//  draft (text vs loadedText) rather than a separate tracked set, and the
//  draft survives across simulated unmount/remount of EnvFileEditorView
//  (a tab switch) — the bug this store exists to fix.
//

import Foundation
import SwiftData
import Testing
@testable import Devtail

@MainActor
struct WorkspaceSessionDirtyFilesTests {
    private func project(_ name: String) -> Project {
        let p = Project(name: name)
        p.directoryPath = "/tmp/\(name)"
        return p
    }

    private func makeSession() -> WorkspaceSession {
        let engine = MockTerminalEngine()
        let defaults = UserDefaults(suiteName: "WorkspaceSessionDirtyFilesTests-\(UUID().uuidString)")!
        let settings = AppSettings(defaults: defaults)
        let holder = WorkspaceSessionsHolder(engine: engine, browserLauncher: MockBrowserLauncher(), settings: settings)
        let p = project("test")
        return holder.openSession(for: p)
    }

    // MARK: - isDirty derives from the draft

    @Test func newSessionHasNoDirtyFiles() {
        let s = makeSession()
        #expect(s.isDirty(path: "/tmp/.env") == false)
    }

    @Test func creatingDraftWithSameTextIsNotDirty() {
        let s = makeSession()
        s.createDraftIfNeeded(for: "/tmp/.env", loadedText: "A=1", recordedModificationDate: nil)
        #expect(s.isDirty(path: "/tmp/.env") == false)
    }

    @Test func updatingDraftTextAwayFromLoadedTextMarksDirty() {
        let s = makeSession()
        s.createDraftIfNeeded(for: "/tmp/.env", loadedText: "A=1", recordedModificationDate: nil)
        s.updateDraft(text: "A=2", for: "/tmp/.env")
        #expect(s.isDirty(path: "/tmp/.env") == true)
    }

    @Test func updatingDraftTextBackToLoadedTextClearsDirty() {
        let s = makeSession()
        s.createDraftIfNeeded(for: "/tmp/.env", loadedText: "A=1", recordedModificationDate: nil)
        s.updateDraft(text: "A=2", for: "/tmp/.env")
        s.updateDraft(text: "A=1", for: "/tmp/.env")
        #expect(s.isDirty(path: "/tmp/.env") == false)
    }

    @Test func dirtyTrackingIsPerFile() {
        let s = makeSession()
        s.createDraftIfNeeded(for: "/tmp/.env", loadedText: "A=1", recordedModificationDate: nil)
        s.updateDraft(text: "A=2", for: "/tmp/.env")
        #expect(s.isDirty(path: "/tmp/.env.local") == false)
    }

    @Test func closingFileClearsDraftAndDirtyState() {
        let s = makeSession()
        s.openFile(at: "/tmp/.env")
        s.createDraftIfNeeded(for: "/tmp/.env", loadedText: "A=1", recordedModificationDate: nil)
        s.updateDraft(text: "A=2", for: "/tmp/.env")
        s.closeFile(at: "/tmp/.env")
        #expect(s.isDirty(path: "/tmp/.env") == false)
        #expect(s.draft(for: "/tmp/.env") == nil)
    }

    // MARK: - Draft survives simulated unmount/remount (the critical fix)

    @Test func draftSurvivesSimulatedUnmountAndRemount() {
        let s = makeSession()
        // Mount: editor creates the draft.
        s.createDraftIfNeeded(for: "/tmp/.env", loadedText: "A=1", recordedModificationDate: nil)
        s.updateDraft(text: "A=2\nB=3", for: "/tmp/.env")

        // Simulate unmount: nothing happens to session state (view just
        // disappears — no onDisappear cleanup of the draft).

        // Simulate remount: the editor calls createDraftIfNeeded again with
        // the same loadedText it would reload from disk. Because a draft
        // already exists, it must NOT be overwritten/reset.
        s.createDraftIfNeeded(for: "/tmp/.env", loadedText: "A=1", recordedModificationDate: nil)

        #expect(s.draft(for: "/tmp/.env")?.text == "A=2\nB=3")
        #expect(s.isDirty(path: "/tmp/.env") == true)
    }

    // MARK: - Save and close (session-level, no mounted view required)

    private func makeEnvFile(_ contents: String) throws -> (URL, () -> Void) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-envdraft-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(".env")
        try Data(contents.utf8).write(to: url)
        return (url, { try? FileManager.default.removeItem(at: folder) })
    }

    @Test func saveAndCloseWritesDraftToDiskAndClosesTab() throws {
        let (url, cleanup) = try makeEnvFile("A=1\n")
        defer { cleanup() }
        let s = makeSession()
        s.openFile(at: url.path)
        let recorded = EnvFileSaver.modificationDate(at: url.path)
        s.createDraftIfNeeded(for: url.path, loadedText: "A=1\n", recordedModificationDate: recorded)
        s.updateDraft(text: "A=2\n", for: url.path)

        s.saveAndCloseFile(at: url.path)

        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(written == "A=2\n")
        #expect(s.openFiles.contains { $0.path == url.path } == false)
        #expect(s.draft(for: url.path) == nil)
    }

    @Test func saveAndCloseOnConflictDoesNotCloseAndSelectsTheTab() throws {
        let (url, cleanup) = try makeEnvFile("A=1\n")
        defer { cleanup() }
        let s = makeSession()
        s.openFile(at: url.path)
        let recorded = EnvFileSaver.modificationDate(at: url.path)
        s.createDraftIfNeeded(for: url.path, loadedText: "A=1\n", recordedModificationDate: recorded)
        s.updateDraft(text: "A=2\n", for: url.path)

        // Simulate an external edit after load, changing the on-disk mtime.
        try Data("A=EXTERNAL\n".utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: (recorded ?? Date()).addingTimeInterval(5)],
            ofItemAtPath: url.path
        )

        s.saveAndCloseFile(at: url.path)

        // Tab stays open, selected — so the editor mounts and can show its
        // own conflict alert — and the draft (with the user's unsaved text)
        // is preserved rather than silently overwritten.
        #expect(s.openFiles.contains { $0.path == url.path } == true)
        #expect(s.selectedTab == .file(url.path))
        #expect(s.draft(for: url.path)?.text == "A=2\n")
        #expect(s.envConflictPath == url.path)
        let onDisk = try String(contentsOf: url, encoding: .utf8)
        #expect(onDisk == "A=EXTERNAL\n")
    }

    // MARK: - envConflictPath signal consumption

    @Test func consumeEnvConflictReturnsTrueOnceThenFalse() throws {
        let (url, cleanup) = try makeEnvFile("A=1\n")
        defer { cleanup() }
        let s = makeSession()
        s.openFile(at: url.path)
        let recorded = EnvFileSaver.modificationDate(at: url.path)
        s.createDraftIfNeeded(for: url.path, loadedText: "A=1\n", recordedModificationDate: recorded)
        s.updateDraft(text: "A=2\n", for: url.path)

        try Data("A=EXTERNAL\n".utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: (recorded ?? Date()).addingTimeInterval(5)],
            ofItemAtPath: url.path
        )

        s.saveAndCloseFile(at: url.path)
        #expect(s.envConflictPath == url.path)

        #expect(s.consumeEnvConflict(for: url.path) == true)
        #expect(s.envConflictPath == nil)
        #expect(s.consumeEnvConflict(for: url.path) == false)
    }

    @Test func consumeEnvConflictForNonMatchingPathReturnsFalseAndDoesNotClear() throws {
        let (url, cleanup) = try makeEnvFile("A=1\n")
        defer { cleanup() }
        let s = makeSession()
        s.openFile(at: url.path)
        let recorded = EnvFileSaver.modificationDate(at: url.path)
        s.createDraftIfNeeded(for: url.path, loadedText: "A=1\n", recordedModificationDate: recorded)
        s.updateDraft(text: "A=2\n", for: url.path)

        try Data("A=EXTERNAL\n".utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: (recorded ?? Date()).addingTimeInterval(5)],
            ofItemAtPath: url.path
        )

        s.saveAndCloseFile(at: url.path)

        #expect(s.consumeEnvConflict(for: "/tmp/other-file.env") == false)
        #expect(s.envConflictPath == url.path)
    }
}
