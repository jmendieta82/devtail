//
//  WorkspaceSessionSendTaskTests.swift
//  DevtailTests
//
//  TDD for sending a task board card into an agent tab: the text reaches the
//  targeted agent only, carries the board prefix, selects that tab, and skips
//  dead agents.
//

import Foundation
import Testing
@testable import Devtail

@MainActor
struct WorkspaceSessionSendTaskTests {
    /// Agents are created through the holder (`agents` is fileprivate(set) —
    /// only the holder may seed or append one), so the SUT is a real session
    /// with `agentCount` tabs. The returned mocks are the agents' PTYs in tab
    /// order, which is what the send assertions inspect.
    private func makeSUT(agentCount: Int = 1) -> (WorkspaceSession, [MockTerminalSession]) {
        let defaults = UserDefaults(suiteName: "WorkspaceSessionSendTaskTests-\(UUID().uuidString)")!
        let engine = MockTerminalEngine()
        let holder = WorkspaceSessionsHolder(
            engine: engine, browserLauncher: MockBrowserLauncher(),
            settings: AppSettings(defaults: defaults),
            schedule: { _, _ in }
        )
        let project = Project(name: "demo")
        project.directoryPath = "/tmp/demo"
        let session = holder.openSession(for: project)
        for _ in 1..<max(agentCount, 1) {
            holder.openAgent(projectId: project.id)
        }
        let mocks = session.agents.compactMap { $0.session as? MockTerminalSession }
        return (session, mocks)
    }

    @Test func sendsPrefixedTitleToTargetedAgent() {
        let (session, mocks) = makeSUT(agentCount: 2)

        session.sendTask(title: "Arreglar el PDF", toAgent: session.agents[1].id)

        #expect(mocks[1].bracketedWrites == ["Tarea del board: Arreglar el PDF"])
        #expect(mocks[0].bracketedWrites.isEmpty)
    }

    @Test func selectsTargetedAgentTab() {
        let (session, _) = makeSUT(agentCount: 2)
        let target = session.agents[1].id

        session.sendTask(title: "Arreglar el PDF", toAgent: target)

        #expect(session.selectedTab == .agent(target))
    }

    @Test func unknownAgentIdIsNoOp() {
        let (session, mocks) = makeSUT(agentCount: 2)
        let original = session.selectedTab

        session.sendTask(title: "Arreglar el PDF", toAgent: UUID())

        #expect(mocks.allSatisfy { $0.bracketedWrites.isEmpty })
        #expect(session.selectedTab == original)
    }

    @Test func liveAgentsExcludesExitedOnes() {
        let (session, _) = makeSUT(agentCount: 3)
        session.agents[1].exited = true

        #expect(session.liveAgents.map(\.title) == ["agent", "agent 3"])
    }
}
