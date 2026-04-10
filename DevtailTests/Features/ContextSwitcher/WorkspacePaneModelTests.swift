//
//  WorkspacePaneModelTests.swift
//  DevtailTests
//
//  Unit tests for the WorkspacePane SwiftData model.
//  No container needed — pure initializer tests.
//

import Testing
import Foundation
@testable import Devtail

@MainActor
@Suite("WorkspacePane model")
struct WorkspacePaneModelTests {

    @Test("initializer sets all fields")
    func initializerSetsAllFields() {
        let project = Project(name: "Devtail")
        let pane = WorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "npm start",
            order: 0,
            layoutSlot: 1,
            project: project
        )
        #expect(pane.label == "Main")
        #expect(pane.relativeCwd == ".")
        #expect(pane.command == "npm start")
        #expect(pane.order == 0)
        #expect(pane.layoutSlot == 1)
        #expect(pane.project?.id == project.id)
    }

    @Test("initializer assigns a non-nil UUID id")
    func initializerAssignsID() {
        let pane = WorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "",
            order: 0,
            layoutSlot: 0,
            project: nil
        )
        let uuidString = pane.id.uuidString
        #expect(UUID(uuidString: uuidString) != nil)
    }

    @Test("initializer generates unique id per instance")
    func initializerGeneratesUniqueIDs() {
        let a = WorkspacePane(label: "A", relativeCwd: ".", command: "", order: 0, layoutSlot: 0, project: nil)
        let b = WorkspacePane(label: "B", relativeCwd: ".", command: "", order: 1, layoutSlot: 1, project: nil)
        #expect(a.id != b.id)
    }

    @Test("initializer sets createdAt equal to updatedAt")
    func initializerSetsTimestamps() {
        let pane = WorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "",
            order: 0,
            layoutSlot: 0,
            project: nil
        )
        #expect(pane.createdAt == pane.updatedAt)
    }

    @Test("project back-reference is set on init")
    func projectBackReferenceSet() {
        let project = Project(name: "Devtail")
        let pane = WorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "",
            order: 0,
            layoutSlot: 0,
            project: project
        )
        #expect(pane.project?.id == project.id)
    }

    @Test("layoutSlot -1 (unassigned sentinel) is stored as-is")
    func layoutSlotSentinel() {
        let pane = WorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "",
            order: 0,
            layoutSlot: -1,
            project: nil
        )
        #expect(pane.layoutSlot == -1)
    }
}
