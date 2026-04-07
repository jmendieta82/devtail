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

    // MARK: - New fields: color, environment, stack

    @Test("initializer defaults color to .gray when omitted")
    func initializerDefaultsColorToGray() {
        let project = Project(name: "My Project")

        #expect(project.color == .gray)
    }

    @Test("initializer defaults environment to .dev when omitted")
    func initializerDefaultsEnvironmentToDev() {
        let project = Project(name: "My Project")

        #expect(project.environment == .dev)
    }

    @Test("initializer defaults stack to nil when omitted")
    func initializerDefaultsStackToNil() {
        let project = Project(name: "My Project")

        #expect(project.stack == nil)
    }

    @Test("initializer assigns color, environment, and stack when provided")
    func initializerAssignsNewFields() {
        let project = Project(
            name: "Devtail",
            notes: nil,
            color: .green,
            environment: .prod,
            stack: "Swift + SwiftUI"
        )

        #expect(project.color == .green)
        #expect(project.environment == .prod)
        #expect(project.stack == "Swift + SwiftUI")
    }
}
