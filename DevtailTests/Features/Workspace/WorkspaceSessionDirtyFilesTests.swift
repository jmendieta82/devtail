//
//  WorkspaceSessionDirtyFilesTests.swift
//  DevtailTests
//
//  TDD for WorkspaceSession's dirty-path tracking surface: env-file editors
//  report dirty/clean into the session, and the tab chip / close guard read
//  it back. Mirrors the setup in WorkspaceSessionOpenFilesTests.
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

    @Test func newSessionHasNoDirtyFiles() {
        let s = makeSession()
        #expect(s.isDirty(path: "/tmp/.env") == false)
    }

    @Test func settingDirtyMarksFile() {
        let s = makeSession()
        s.setDirty(true, path: "/tmp/.env")
        #expect(s.isDirty(path: "/tmp/.env") == true)
    }

    @Test func clearingDirtyUnmarksFile() {
        let s = makeSession()
        s.setDirty(true, path: "/tmp/.env")
        s.setDirty(false, path: "/tmp/.env")
        #expect(s.isDirty(path: "/tmp/.env") == false)
    }

    @Test func dirtyTrackingIsPerFile() {
        let s = makeSession()
        s.setDirty(true, path: "/tmp/.env")
        #expect(s.isDirty(path: "/tmp/.env.local") == false)
    }

    @Test func closingFileClearsDirtyState() {
        let s = makeSession()
        s.openFile(at: "/tmp/.env")
        s.setDirty(true, path: "/tmp/.env")
        s.closeFile(at: "/tmp/.env")
        #expect(s.isDirty(path: "/tmp/.env") == false)
    }
}
