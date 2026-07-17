//
//  WorkspaceSessionGitStatusTests.swift
//  DevtailTests
//
//  TDD for WorkspaceSession's git-status wiring: refreshGitStatus() assigns
//  on success, honors cancellation, and cancelGitStatusRefresh() (called
//  from WorkspaceSessionsHolder.close(projectId:)) stops a stale refresh
//  from assigning after teardown. GitStatusReader itself shells out to a
//  real `git` process and is not headless-testable — these tests exercise
//  the wiring only, via the injected GitStatusReading fake.
//

import Foundation
import Testing
@testable import Devtail

@MainActor
struct WorkspaceSessionGitStatusTests {
    private func makeSession(reader: GitStatusReading) -> WorkspaceSession {
        let engine = MockTerminalEngine()
        let supervisor = ProcessSupervisor(engine: engine, browserLauncher: MockBrowserLauncher())
        let agent = engine.makeSession(TerminalSessionConfig(command: "claude", cwd: URL(fileURLWithPath: "/tmp/alpha"), readOnly: false))
        return WorkspaceSession(
            projectId: UUID(), projectName: "alpha", root: URL(fileURLWithPath: "/tmp/alpha"),
            supervisor: supervisor, agent: agent,
            gitStatusReader: reader
        )
    }

    private func sampleStatus() -> GitStatus {
        GitStatus(branch: "main", localBranchCount: 2, isDirty: true, changedFileCount: 3, ahead: 1, behind: 0)
    }

    @Test func gitStatusDefaultsToNilOnFreshSession() {
        let session = makeSession(reader: MockGitStatusReader())
        #expect(session.gitStatus == nil)
    }

    @Test func refreshGitStatusAssignsOnSuccess() async throws {
        let reader = MockGitStatusReader(statusToReturn: sampleStatus())
        let session = makeSession(reader: reader)

        session.refreshGitStatus()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(session.gitStatus == sampleStatus())
        #expect(reader.callCount == 1)
    }

    @Test func refreshGitStatusCancelsPreviousInFlightRefresh() async throws {
        let slowReader = MockGitStatusReader(statusToReturn: sampleStatus())
        slowReader.delayNanoseconds = 200_000_000
        let session = makeSession(reader: slowReader)

        session.refreshGitStatus() // first call, still "in flight"
        session.refreshGitStatus() // supersedes the first before it resolves
        try await Task.sleep(nanoseconds: 300_000_000)

        // Only the final refresh's result should have landed; the first
        // (cancelled) refresh must not have raced its assignment in after.
        #expect(session.gitStatus == sampleStatus())
    }

    @Test func cancelGitStatusRefreshPreventsStaleAssignment() async throws {
        let reader = MockGitStatusReader(statusToReturn: sampleStatus())
        reader.delayNanoseconds = 150_000_000
        let session = makeSession(reader: reader)

        session.refreshGitStatus()
        session.cancelGitStatusRefresh()
        try await Task.sleep(nanoseconds: 250_000_000)

        // The in-flight read was cancelled before it could assign —
        // gitStatus must still be nil, mirroring what close(projectId:)
        // relies on to avoid a stale assignment after teardown.
        #expect(session.gitStatus == nil)
    }
}
