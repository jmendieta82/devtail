//
//  WorkspaceSessionsHolderTests.swift
//  DevtailTests
//
//  TDD for WorkspaceSessionsHolder: app-level owner of live workspace
//  sessions, keyed by project id. Verifies idempotent open, root cwd wiring,
//  and that close/shutdownAll terminate every underlying terminal session.
//

import Foundation
import SwiftData
import Testing
@testable import Devtail

@MainActor
struct WorkspaceSessionsHolderTests {
    private func makeSUT() -> (WorkspaceSessionsHolder, MockTerminalEngine) {
        let engine = MockTerminalEngine()
        let holder = WorkspaceSessionsHolder(engine: engine, browserLauncher: MockBrowserLauncher())
        return (holder, engine)
    }

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

    @Test func closeShutsDownProcessesAndTerminal() throws {
        let (holder, engine) = makeSUT()
        let context = try makeContext()
        let p = project("alpha")
        context.insert(p)
        let pane = WorkspacePane(label: "back", relativeCwd: "api", command: "npm run dev",
                                  order: 0, layoutSlot: 0, project: p)
        context.insert(pane)
        p.workspacePanes.append(pane)

        _ = holder.openSession(for: p)
        // 1 interactive terminal + 1 managed process session.
        #expect(engine.sessions.count == 2)

        holder.close(projectId: p.id)
        #expect(!holder.isOpen(p.id))
        // Proves the holder propagates teardown through the supervisor to
        // every underlying session, not just the interactive terminal.
        #expect(engine.sessions.count == 2)
        #expect(engine.sessions.allSatisfy { $0.terminateCount >= 1 })
    }

    @Test func shutdownAllClosesEveryOpenWorkspace() {
        let (holder, engine) = makeSUT()
        _ = holder.openSession(for: project("a"))
        _ = holder.openSession(for: project("b"))
        holder.shutdownAll()
        #expect(engine.sessions.allSatisfy { $0.terminateCount >= 1 })
    }

    // MARK: - currentBranch / quickLinks population

    /// Writes a `.git/HEAD` file with the given contents under `folder`.
    /// Mirrors the fixture pattern in GitBranchDetectorTests.
    private func makeGitDir(in folder: URL, head: String) throws {
        let gitDir = folder.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
        let headURL = gitDir.appendingPathComponent("HEAD")
        try head.data(using: .utf8)!.write(to: headURL)
    }

    @Test func openSessionDetectsCurrentBranchFromProjectRoot() throws {
        let (holder, _) = makeSUT()
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-workspace-session-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try makeGitDir(in: folder, head: "ref: refs/heads/main\n")

        let p = project("alpha")
        p.directoryPath = folder.path

        let session = holder.openSession(for: p)

        #expect(session.currentBranch == "main")
    }

    @Test func openSessionPopulatesQuickLinksSortedByOrder() throws {
        let (holder, _) = makeSUT()
        let context = try makeContext()
        let p = project("alpha")
        context.insert(p)

        let second = QuickLink(label: "Docs", url: "https://docs.example.com", order: 1, project: p)
        let first = QuickLink(label: "GitHub", url: "https://github.com", order: 0, project: p)
        context.insert(second)
        context.insert(first)
        p.quickLinks.append(contentsOf: [second, first])

        let session = holder.openSession(for: p)

        #expect(session.quickLinks.map(\.title) == ["GitHub", "Docs"])
        #expect(session.quickLinks.map(\.url) == ["https://github.com", "https://docs.example.com"])
    }

    @Test func openSessionWithNoGitAndNoLinksLeavesBranchNilAndLinksEmpty() {
        let (holder, _) = makeSUT()
        let p = project("alpha")

        let session = holder.openSession(for: p)

        #expect(session.currentBranch == nil)
        #expect(session.quickLinks.isEmpty)
    }
}
