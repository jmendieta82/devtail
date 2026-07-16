//
//  ProcessSupervisorReconfigureTests.swift
//  DevtailTests
//
//  Incremental reconfigure after a settings edit: surviving panes keep
//  their ManagedProcess (and live session) by pane id, removed panes are
//  closed, new panes appear as stopped cards. Same mock setup as
//  ProcessSupervisorTests.
//

import Foundation
import Testing
@testable import Devtail

@MainActor
struct ProcessSupervisorReconfigureTests {
    private func makeSupervisor() -> (ProcessSupervisor, MockTerminalEngine) {
        let engine = MockTerminalEngine()
        return (ProcessSupervisor(engine: engine, browserLauncher: MockBrowserLauncher()), engine)
    }
    private let root = URL(fileURLWithPath: "/tmp/reconf")

    @Test func survivingRunningPaneKeepsItsSessionAndState() {
        let (supervisor, _) = makeSupervisor()
        let pane = WorkspacePane(label: "api", relativeCwd: "api", command: "npm start",
                                 order: 0, layoutSlot: 0, project: nil)
        supervisor.configure(panes: [pane], root: root)
        supervisor.start(supervisor.processes[0])
        let session = supervisor.processes[0].session
        #expect(supervisor.processes[0].state == .running)

        supervisor.reconfigure(panes: [pane], root: root)

        #expect(supervisor.processes.count == 1)
        #expect(supervisor.processes[0].session === session)
        #expect(supervisor.processes[0].state == .running)
    }

    @Test func removedPaneIsClosedAndDisappears() {
        let (supervisor, engine) = makeSupervisor()
        let keep = WorkspacePane(label: "api", relativeCwd: "api", command: "npm start",
                                 order: 0, layoutSlot: 0, project: nil)
        let drop = WorkspacePane(label: "web", relativeCwd: "web", command: "ng serve",
                                 order: 1, layoutSlot: 0, project: nil)
        supervisor.configure(panes: [keep, drop], root: root)
        supervisor.start(supervisor.processes[1])

        supervisor.reconfigure(panes: [keep], root: root)

        #expect(supervisor.processes.map(\.name) == ["api"])
        // The removed pane's session was terminated, same mechanism as the
        // existing close tests in ProcessSupervisorTests.
        #expect(engine.sessions[0].terminateCount == 1)
    }

    @Test func newPaneAppearsStoppedAndNotStarted() {
        let (supervisor, _) = makeSupervisor()
        let a = WorkspacePane(label: "api", relativeCwd: "api", command: "npm start",
                              order: 0, layoutSlot: 0, project: nil)
        supervisor.configure(panes: [a], root: root)
        let b = WorkspacePane(label: "web", relativeCwd: "web", command: "ng serve",
                              order: 1, layoutSlot: 0, project: nil)

        supervisor.reconfigure(panes: [a, b], root: root)

        #expect(supervisor.processes.map(\.name) == ["api", "web"])
        #expect(supervisor.processes[1].state == .stopped)
        #expect(supervisor.processes[1].session == nil)
    }

    @Test func changedCommandOnRunningProcessAppliesOnNextStart() {
        let (supervisor, engine) = makeSupervisor()
        let pane = WorkspacePane(label: "api", relativeCwd: "api", command: "npm start",
                                 order: 0, layoutSlot: 0, project: nil)
        supervisor.configure(panes: [pane], root: root)
        supervisor.start(supervisor.processes[0])
        pane.command = "npm run dev"

        supervisor.reconfigure(panes: [pane], root: root)
        #expect(supervisor.processes[0].state == .running) // does not kill it

        supervisor.restart(supervisor.processes[0])
        // The engine's last spawn config used the new command.
        #expect(engine.configs.last?.command == "npm run dev")
    }

    @Test func blankCommandPanesAreFilteredOut() {
        let (supervisor, _) = makeSupervisor()
        let a = WorkspacePane(label: "api", relativeCwd: "api", command: "npm start",
                              order: 0, layoutSlot: 0, project: nil)
        supervisor.configure(panes: [a], root: root)
        let blank = WorkspacePane(label: "todo", relativeCwd: ".", command: "  ",
                                  order: 1, layoutSlot: 0, project: nil)

        supervisor.reconfigure(panes: [a, blank], root: root)

        #expect(supervisor.processes.map(\.name) == ["api"])
    }

    @Test func reconfigureRespectsPaneOrder() {
        let (supervisor, _) = makeSupervisor()
        let a = WorkspacePane(label: "api", relativeCwd: "api", command: "npm start",
                              order: 5, layoutSlot: 0, project: nil)
        let b = WorkspacePane(label: "web", relativeCwd: "web", command: "ng serve",
                              order: 1, layoutSlot: 0, project: nil)
        supervisor.configure(panes: [a], root: root)

        supervisor.reconfigure(panes: [a, b], root: root)

        #expect(supervisor.processes.map(\.name) == ["web", "api"])
    }

    @Test func renamedPaneUpdatesCardName() {
        let (supervisor, _) = makeSupervisor()
        let pane = WorkspacePane(label: "api", relativeCwd: "api", command: "npm start",
                                 order: 0, layoutSlot: 0, project: nil)
        supervisor.configure(panes: [pane], root: root)
        pane.label = "backend"

        supervisor.reconfigure(panes: [pane], root: root)

        #expect(supervisor.processes[0].name == "backend")
    }
}
