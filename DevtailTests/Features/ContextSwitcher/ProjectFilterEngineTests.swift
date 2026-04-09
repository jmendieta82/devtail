//
//  ProjectFilterEngineTests.swift
//  DevtailTests
//
//  Tests the pure filter engine that powers project search across the
//  menubar and (later) the dashboard. The engine is intentionally
//  state-free, so every test just builds an input array, calls
//  `filter(projects:query:)`, and asserts on the output.
//
//  Project objects are created via the SwiftData in-memory container so
//  the @Model machinery is initialised correctly — Project is a class
//  (reference type) and we want real instances, not stubs.
//

import Testing
import Foundation
import SwiftData
@testable import Devtail

@Suite("ProjectFilterEngine")
@MainActor
struct ProjectFilterEngineTests {

    // MARK: - Fixture helpers

    /// Builds an in-memory ModelContainer + a few projects with the
    /// fields we want to match against. Reused across tests to keep
    /// each one focused on the assertion, not the setup.
    private func makeProjects() -> [Project] {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext

        let devtail = Project(name: "Devtail", color: .green)
        devtail.directoryPath = "/Users/dev/Code/Devtail"

        let mrn = Project(name: "MRN_V2", color: .blue)
        mrn.directoryPath = "/Users/dev/Code/mrn-app"

        let pixel = Project(name: "Pixel Dashboard", color: .purple)
        pixel.directoryPath = "/Users/dev/Code/pixel"

        let inclusion = Project(name: "Inclusion", color: .amber)
        inclusion.directoryPath = "/Users/dev/work/inclusion-bienestar"

        for project in [devtail, mrn, pixel, inclusion] {
            context.insert(project)
        }

        return [devtail, mrn, pixel, inclusion]
    }

    // MARK: - Empty / whitespace queries

    @Test("empty query returns the input unchanged")
    func emptyQueryReturnsAll() {
        let projects = makeProjects()
        let engine = ProjectFilterEngine()

        let result = engine.filter(projects: projects, query: "")

        #expect(result.count == projects.count)
        #expect(result.map(\.id) == projects.map(\.id))
    }

    @Test("whitespace-only query returns the input unchanged")
    func whitespaceOnlyQueryReturnsAll() {
        let projects = makeProjects()
        let engine = ProjectFilterEngine()

        let result = engine.filter(projects: projects, query: "   ")

        #expect(result.count == projects.count)
    }

    @Test("query with leading and trailing whitespace is trimmed")
    func queryIsTrimmed() {
        let projects = makeProjects()
        let engine = ProjectFilterEngine()

        let result = engine.filter(projects: projects, query: "  devtail  ")

        #expect(result.count == 1)
        #expect(result.first?.name == "Devtail")
    }

    // MARK: - Name matching

    @Test("matches by name, case-insensitive")
    func matchesByNameCaseInsensitive() {
        let projects = makeProjects()
        let engine = ProjectFilterEngine()

        let result = engine.filter(projects: projects, query: "DEVTAIL")

        #expect(result.count == 1)
        #expect(result.first?.name == "Devtail")
    }

    @Test("substring inside name matches")
    func substringInsideName() {
        let projects = makeProjects()
        let engine = ProjectFilterEngine()

        let result = engine.filter(projects: projects, query: "ash")

        // "Pixel Dashboard" contains "ash"
        #expect(result.count == 1)
        #expect(result.first?.name == "Pixel Dashboard")
    }

    // MARK: - Directory path matching

    @Test("matches by directoryPath when name does not match")
    func matchesByDirectoryPath() {
        let projects = makeProjects()
        let engine = ProjectFilterEngine()

        // "mrn-app" lives in directoryPath, not in the project name
        // (which is "MRN_V2" — without dashes).
        let result = engine.filter(projects: projects, query: "mrn-app")

        #expect(result.count == 1)
        #expect(result.first?.name == "MRN_V2")
    }

    @Test("directoryPath substring also matches case-insensitively")
    func directoryPathCaseInsensitive() {
        let projects = makeProjects()
        let engine = ProjectFilterEngine()

        let result = engine.filter(projects: projects, query: "BIENESTAR")

        #expect(result.count == 1)
        #expect(result.first?.name == "Inclusion")
    }

    // MARK: - No matches

    @Test("returns empty array when no project matches")
    func noMatchReturnsEmpty() {
        let projects = makeProjects()
        let engine = ProjectFilterEngine()

        let result = engine.filter(projects: projects, query: "xyz-no-such-project")

        #expect(result.isEmpty)
    }

    // MARK: - Ordering

    @Test("preserves the input order of matching projects")
    func preservesInputOrder() {
        let projects = makeProjects()
        let engine = ProjectFilterEngine()

        // All 4 projects have "/Users/dev/" in their path, so all match.
        let result = engine.filter(projects: projects, query: "/Users/dev")

        #expect(result.map(\.id) == projects.map(\.id))
    }

    // MARK: - Edge cases

    @Test("empty input array stays empty regardless of query")
    func emptyInputStaysEmpty() {
        let engine = ProjectFilterEngine()

        let result = engine.filter(projects: [], query: "anything")

        #expect(result.isEmpty)
    }

    @Test("project with empty directoryPath still matches by name")
    func emptyDirectoryPathStillMatchesByName() {
        let container = PersistenceController.makeContainer(inMemory: true)
        let project = Project(name: "Bare", color: .gray)
        // directoryPath stays "" (default)
        container.mainContext.insert(project)

        let engine = ProjectFilterEngine()
        let result = engine.filter(projects: [project], query: "bare")

        #expect(result.count == 1)
    }
}
