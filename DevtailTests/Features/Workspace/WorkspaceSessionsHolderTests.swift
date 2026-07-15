//
//  WorkspaceSessionsHolderTests.swift
//  DevtailTests
//
//  TDD for WorkspaceSessionsHolder: app-level owner of live workspace
//  sessions, keyed by project id. Verifies idempotent open, root cwd wiring,
//  and that close/shutdownAll terminate every underlying terminal session.
//

import Foundation
import Testing
@testable import Devtail

@MainActor
struct WorkspaceSessionsHolderTests {
    private func makeSUT() -> (WorkspaceSessionsHolder, MockTerminalEngine) {
        let engine = MockTerminalEngine()
        let holder = WorkspaceSessionsHolder(engine: engine, browserLauncher: MockBrowserLauncher())
        return (holder, engine)
    }

    /// `Project`'s designated init only takes name/notes/color — directoryPath
    /// is a separate mutable stored property (default ""), so it's set here.
    private func project(_ name: String) -> Project {
        let p = Project(name: name)
        p.directoryPath = "/tmp/\(name)"
        return p
    }

    @Test func openSessionSpawnsInteractiveTerminalAtRootAndIsIdempotent() {
        let (holder, engine) = makeSUT()
        let p = project("alpha")
        let s1 = holder.openSession(for: p)
        let s2 = holder.openSession(for: p)
        #expect(s1 === s2)
        // Exactly one interactive (non-readOnly, nil command) session at the root.
        #expect(engine.configs.count { !$0.readOnly } == 1)
        let interactive = engine.configs.first { !$0.readOnly }
        #expect(interactive?.command == nil)
        #expect(interactive?.cwd.path == "/tmp/alpha")
        #expect(holder.isOpen(p.id))
    }

    @Test func closeShutsDownProcessesAndTerminal() {
        let (holder, engine) = makeSUT()
        let p = project("alpha")
        _ = holder.openSession(for: p)
        holder.close(projectId: p.id)
        #expect(!holder.isOpen(p.id))
        #expect(engine.sessions.allSatisfy { $0.terminateCount >= 1 })
    }

    @Test func shutdownAllClosesEveryOpenWorkspace() {
        let (holder, engine) = makeSUT()
        _ = holder.openSession(for: project("a"))
        _ = holder.openSession(for: project("b"))
        holder.shutdownAll()
        #expect(engine.sessions.allSatisfy { $0.terminateCount >= 1 })
    }
}
