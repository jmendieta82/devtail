//
//  ProjectModelTests.swift
//  DevtailTests
//
//  Tests for the Project SwiftData model.
//

import Testing
import Foundation
@testable import Devtail

@MainActor
@Suite("Project model")
struct ProjectModelTests {

    @Test("initializer assigns name and notes")
    func initializerSetsNameAndNotes() {
        let project = Project(name: "My Project", notes: "some notes")

        #expect(project.name == "My Project")
        #expect(project.notes == "some notes")
    }

    @Test("initializer defaults notes to nil when omitted")
    func initializerDefaultsNotesToNil() {
        let project = Project(name: "My Project")

        #expect(project.notes == nil)
    }

    @Test("initializer sets createdAt and updatedAt to the same value")
    func initializerSetsCreatedAtAndUpdatedAtToSameValue() {
        let project = Project(name: "My Project")

        #expect(project.createdAt == project.updatedAt)
    }

    @Test("initializer assigns a unique id to each instance")
    func initializerAssignsUniqueId() {
        let p1 = Project(name: "Project A")
        let p2 = Project(name: "Project B")

        #expect(p1.id != p2.id)
    }

    // MARK: - Color field

    @Test("initializer defaults color to .gray when omitted")
    func initializerDefaultsColorToGray() {
        let project = Project(name: "My Project")

        #expect(project.color == .gray)
    }

    @Test("initializer assigns color when provided")
    func initializerAssignsColor() {
        let project = Project(
            name: "Devtail",
            notes: nil,
            color: .green
        )

        #expect(project.color == .green)
    }

    // MARK: - Environment moved to WorkspacePane

    @Test("WorkspacePane defaults environment to nil when omitted")
    func paneDefaultsEnvironmentToNil() {
        let pane = WorkspacePane(
            label: "frontend",
            relativeCwd: "frontend",
            command: "",
            order: 0,
            layoutSlot: 0,
            project: nil
        )

        #expect(pane.environment == nil)
    }

    @Test("WorkspacePane assigns environment when provided")
    func paneAssignsEnvironment() {
        let pane = WorkspacePane(
            label: "backend",
            relativeCwd: "backend",
            command: "python manage.py runserver",
            order: 1,
            layoutSlot: 1,
            stack: "Django",
            environment: .prod,
            project: nil
        )

        #expect(pane.environment == .prod)
    }
}
