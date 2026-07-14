//
//  WorkspacePaneModelTests.swift
//  DevtailTests
//
//  Unit tests for the WorkspacePane SwiftData model.
//

import Testing
import Foundation
import SwiftData
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

    // MARK: - isFrontend and localhostUrl

    @Test("isFrontend defaults to false when omitted")
    func isFrontendDefaultsFalse() {
        let pane = WorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "",
            order: 0,
            layoutSlot: 0,
            project: nil
        )
        #expect(pane.isFrontend == false)
    }

    @Test("localhostUrl defaults to nil when omitted")
    func localhostUrlDefaultsNil() {
        let pane = WorkspacePane(
            label: "Main",
            relativeCwd: ".",
            command: "",
            order: 0,
            layoutSlot: 0,
            project: nil
        )
        #expect(pane.localhostUrl == nil)
    }

    @Test("explicit init with isFrontend:true and localhostUrl persists both values")
    func explicitFrontendFields() {
        let pane = WorkspacePane(
            label: "frontend",
            relativeCwd: "frontend",
            command: "npm run dev",
            order: 0,
            layoutSlot: 0,
            isFrontend: true,
            localhostUrl: "http://localhost:4200",
            project: nil
        )
        #expect(pane.isFrontend == true)
        #expect(pane.localhostUrl == "http://localhost:4200")
    }

    @Test("SwiftData in-memory round-trip: isFrontend defaults to false, localhostUrl to nil")
    func swiftDataRoundTripDefaultFrontendFields() throws {
        let schema = Schema([Project.self, QuickLink.self, WorkspacePane.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let project = Project(name: "Test Project")
        context.insert(project)
        let pane = WorkspacePane(
            label: "backend",
            relativeCwd: "backend",
            command: "",
            order: 0,
            layoutSlot: 0,
            project: project
        )
        context.insert(pane)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WorkspacePane>())
        #expect(fetched.count == 1)
        #expect(fetched[0].isFrontend == false)
        #expect(fetched[0].localhostUrl == nil)
    }

    @Test("SwiftData in-memory round-trip: isFrontend=true and localhostUrl persisted correctly")
    func swiftDataRoundTripFrontendPersisted() throws {
        let schema = Schema([Project.self, QuickLink.self, WorkspacePane.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let project = Project(name: "Test Project")
        context.insert(project)
        let pane = WorkspacePane(
            label: "app",
            relativeCwd: "app",
            command: "npm run dev",
            order: 0,
            layoutSlot: 0,
            isFrontend: true,
            localhostUrl: "http://localhost:3000",
            project: project
        )
        context.insert(pane)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WorkspacePane>())
        #expect(fetched.count == 1)
        #expect(fetched[0].isFrontend == true)
        #expect(fetched[0].localhostUrl == "http://localhost:3000")
    }
}
