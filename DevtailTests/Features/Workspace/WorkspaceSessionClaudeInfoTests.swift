//
//  WorkspaceSessionClaudeInfoTests.swift
//  DevtailTests
//
//  TDD for WorkspaceSession's claude-info wiring: refreshClaudeInfo()
//  assigns on success, honors cancellation, and cancelClaudeInfoRefresh()
//  (called from WorkspaceSessionsHolder.close(projectId:)) stops a stale
//  refresh from assigning after teardown. Mirrors
//  WorkspaceSessionGitStatusTests exactly — same wiring pattern, different
//  seam.
//

import Foundation
import Testing
@testable import Devtail

@MainActor
struct WorkspaceSessionClaudeInfoTests {
    private func makeSession(introspector: ClaudeIntrospecting) -> WorkspaceSession {
        let engine = MockTerminalEngine()
        let supervisor = ProcessSupervisor(engine: engine, browserLauncher: MockBrowserLauncher())
        let agent = engine.makeSession(TerminalSessionConfig(command: "claude", cwd: URL(fileURLWithPath: "/tmp/alpha"), readOnly: false))
        return WorkspaceSession(
            projectId: UUID(), projectName: "alpha", root: URL(fileURLWithPath: "/tmp/alpha"),
            supervisor: supervisor, agent: agent,
            claudeIntrospector: introspector
        )
    }

    private func sampleIntrospection() -> ClaudeIntrospection {
        ClaudeIntrospection(
            skills: [ClaudeItem(name: "skill-a", detail: "desc", scope: .project)],
            agents: [],
            commands: [],
            mcpServers: ["server-a"],
            tokenUsage: TokenUsage(input: 10, output: 5, cache: 2)
        )
    }

    @Test func claudeInfoDefaultsToNilOnFreshSession() {
        let session = makeSession(introspector: MockClaudeIntrospector())
        #expect(session.claudeInfo == nil)
    }

    @Test func refreshClaudeInfoAssignsOnSuccess() async throws {
        let introspector = MockClaudeIntrospector(resultToReturn: sampleIntrospection())
        let session = makeSession(introspector: introspector)

        session.refreshClaudeInfo()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(session.claudeInfo?.mcpServers == ["server-a"])
        #expect(introspector.callCount == 1)
    }

    @Test func refreshClaudeInfoCancelsPreviousInFlightRefresh() async throws {
        let slowIntrospector = MockClaudeIntrospector(resultToReturn: sampleIntrospection())
        slowIntrospector.delayNanoseconds = 200_000_000
        let session = makeSession(introspector: slowIntrospector)

        session.refreshClaudeInfo() // first call, still "in flight"
        session.refreshClaudeInfo() // supersedes the first before it resolves
        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(session.claudeInfo?.mcpServers == ["server-a"])
    }

    @Test func cancelClaudeInfoRefreshPreventsStaleAssignment() async throws {
        let introspector = MockClaudeIntrospector(resultToReturn: sampleIntrospection())
        introspector.delayNanoseconds = 150_000_000
        let session = makeSession(introspector: introspector)

        session.refreshClaudeInfo()
        session.cancelClaudeInfoRefresh()
        try await Task.sleep(nanoseconds: 250_000_000)

        #expect(session.claudeInfo == nil)
    }
}
