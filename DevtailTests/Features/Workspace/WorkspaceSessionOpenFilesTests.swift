//
//  WorkspaceSessionOpenFilesTests.swift
//  DevtailTests
//
//  TDD for WorkspaceSession.openFile/closeFile: open/close file tabs in the
//  workspace center column, tracking which file is currently selected.
//

import Foundation
import SwiftData
import Testing
@testable import Devtail

@MainActor
struct WorkspaceSessionOpenFilesTests {
    // MARK: - Helpers

    /// In-memory ModelContainer so a `WorkspacePane` can be attached to a
    /// `Project` via the SwiftData relationship (`project.workspacePanes`)
    /// without crashing — a context-less `Project` cannot own relationship
    /// data. Mirrors the pattern in WorkspacePaneRepositoryTests.
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Project.self, QuickLink.self, WorkspacePane.self,
            configurations: config
        )
        return ModelContext(container)
    }

    /// `Project`'s designated init only takes name/notes/color — directoryPath
    /// is a separate mutable stored property (default ""), so it's set here.
    private func project(_ name: String) -> Project {
        let p = Project(name: name)
        p.directoryPath = "/tmp/\(name)"
        return p
    }

    /// Creates a WorkspaceSession with mocked dependencies, same pattern as
    /// WorkspaceSessionsHolderTests.makeSUT().
    private func makeSession() -> WorkspaceSession {
        let engine = MockTerminalEngine()
        let holder = WorkspaceSessionsHolder(engine: engine, browserLauncher: MockBrowserLauncher())
        let p = project("test")
        return holder.openSession(for: p)
    }

    // MARK: - Tests

    @Test func openAppendsAndSelects() {
        let s = makeSession()
        s.openFile(at: "/tmp/a.swift")
        #expect(s.openFiles.map(\.path) == ["/tmp/a.swift"])
        #expect(s.selectedTab == .file("/tmp/a.swift"))
    }

    @Test func openIsIdempotentAndReselects() {
        let s = makeSession()
        s.openFile(at: "/tmp/a.swift")
        s.openFile(at: "/tmp/b.swift")
        s.openFile(at: "/tmp/a.swift")
        #expect(s.openFiles.map(\.path) == ["/tmp/a.swift", "/tmp/b.swift"])
        #expect(s.selectedTab == .file("/tmp/a.swift"))
    }

    @Test func closeSelectedSelectsPreviousNeighbor() {
        let s = makeSession()
        s.openFile(at: "/tmp/a.swift"); s.openFile(at: "/tmp/b.swift"); s.openFile(at: "/tmp/c.swift")
        s.closeFile(at: "/tmp/b.swift")   // b sigue seleccionado? no: c es el seleccionado
        s.openFile(at: "/tmp/b.swift")    // reabrir y seleccionar b
        s.closeFile(at: "/tmp/b.swift")
        #expect(s.selectedTab == .file("/tmp/c.swift"))
    }

    @Test func closeSelectedFirstSelectsNext() {
        let s = makeSession()
        s.openFile(at: "/tmp/a.swift"); s.openFile(at: "/tmp/b.swift")
        s.openFile(at: "/tmp/a.swift")
        s.closeFile(at: "/tmp/a.swift")
        #expect(s.selectedTab == .file("/tmp/b.swift"))
    }

    @Test func closeLastFileSelectsTerminal() {
        let s = makeSession()
        s.openFile(at: "/tmp/a.swift")
        s.closeFile(at: "/tmp/a.swift")
        #expect(s.openFiles.isEmpty)
        #expect(s.selectedTab == .terminal)
    }

    @Test func closeUnselectedKeepsSelection() {
        let s = makeSession()
        s.openFile(at: "/tmp/a.swift"); s.openFile(at: "/tmp/b.swift")
        s.closeFile(at: "/tmp/a.swift")
        #expect(s.selectedTab == .file("/tmp/b.swift"))
    }

    @Test func closeUnknownPathIsNoOp() {
        let s = makeSession()
        s.openFile(at: "/tmp/a.swift")
        s.closeFile(at: "/tmp/zzz.swift")
        #expect(s.openFiles.count == 1)
    }
}
