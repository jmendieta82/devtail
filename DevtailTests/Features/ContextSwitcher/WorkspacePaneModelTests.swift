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
            splitDirection: "right",
            project: project
        )
        #expect(pane.label == "Main")
        #expect(pane.relativeCwd == ".")
        #expect(pane.command == "npm start")
        #expect(pane.order == 0)
        #expect(pane.splitDirection == "right")
        #expect(pane.project?.id == project.id)
    }

    @Test("initializer assigns a non-nil UUID id")
    func initializerAssignsID() {
        let pane = WorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "",
            order: 0,
            splitDirection: "none",
            project: nil
        )
        // UUID is always non-nil; verify it is a valid UUID by round-tripping
        let uuidString = pane.id.uuidString
        #expect(UUID(uuidString: uuidString) != nil)
    }

    @Test("initializer generates unique id per instance")
    func initializerGeneratesUniqueIDs() {
        let a = WorkspacePane(label: "A", relativeCwd: ".", command: "", order: 0, splitDirection: "none", project: nil)
        let b = WorkspacePane(label: "B", relativeCwd: ".", command: "", order: 1, splitDirection: "none", project: nil)
        #expect(a.id != b.id)
    }

    @Test("initializer sets createdAt equal to updatedAt")
    func initializerSetsTimestamps() {
        let pane = WorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "",
            order: 0,
            splitDirection: "none",
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
            splitDirection: "none",
            project: project
        )
        #expect(pane.project?.id == project.id)
    }
}
