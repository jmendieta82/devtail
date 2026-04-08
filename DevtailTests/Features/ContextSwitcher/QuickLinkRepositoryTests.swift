//
//  QuickLinkRepositoryTests.swift
//  DevtailTests
//
//  Tests for the QuickLinkRepository CRUD operations.
//

import Foundation
import Testing
import SwiftData
@testable import Devtail

@MainActor
@Suite("QuickLinkRepository")
struct QuickLinkRepositoryTests {
    let container: ModelContainer
    let context: ModelContext
    let projectRepo: ProjectRepository
    let linkRepo: QuickLinkRepository

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Project.self, QuickLink.self,
            configurations: config
        )
        context = ModelContext(container)
        projectRepo = ProjectRepository(context: context)
        linkRepo = QuickLinkRepository(context: context)
    }

    private func makeProject() throws -> Project {
        try projectRepo.create(name: "Devtail")
    }

    @Test("create persists a quick link with order 0 for the first link")
    func createFirstLink() throws {
        let project = try makeProject()
        let link = try linkRepo.create(label: "GitHub", url: "https://github.com", project: project)
        #expect(link.label == "GitHub")
        #expect(link.url == "https://github.com")
        #expect(link.order == 0)
        #expect(link.project?.id == project.id)
    }

    @Test("create assigns incremental order")
    func createAssignsOrder() throws {
        let project = try makeProject()
        let a = try linkRepo.create(label: "A", url: "https://a.com", project: project)
        let b = try linkRepo.create(label: "B", url: "https://b.com", project: project)
        let c = try linkRepo.create(label: "C", url: "https://c.com", project: project)
        #expect(a.order == 0)
        #expect(b.order == 1)
        #expect(c.order == 2)
    }

    @Test("create auto-prefixes https when scheme is missing")
    func createAutoPrefixesHTTPS() throws {
        let project = try makeProject()
        let link = try linkRepo.create(label: "GitHub", url: "github.com", project: project)
        #expect(link.url == "https://github.com")
    }

    @Test("create throws invalidLabel for empty label")
    func createInvalidLabel() throws {
        let project = try makeProject()
        #expect(throws: QuickLinkError.invalidLabel) {
            try linkRepo.create(label: "  ", url: "https://github.com", project: project)
        }
    }

    @Test("create throws invalidURL for empty url")
    func createInvalidURL() throws {
        let project = try makeProject()
        #expect(throws: QuickLinkError.invalidURL) {
            try linkRepo.create(label: "GitHub", url: "   ", project: project)
        }
    }

    @Test("findByProject returns links sorted by order")
    func findByProjectSorted() throws {
        let project = try makeProject()
        _ = try linkRepo.create(label: "A", url: "https://a.com", project: project)
        _ = try linkRepo.create(label: "B", url: "https://b.com", project: project)
        _ = try linkRepo.create(label: "C", url: "https://c.com", project: project)
        let result = try linkRepo.findByProject(project)
        #expect(result.map(\.order) == [0, 1, 2])
    }

    @Test("update bumps updatedAt and persists changes")
    func updateBumpsTimestamp() async throws {
        let project = try makeProject()
        let link = try linkRepo.create(label: "GitHub", url: "https://github.com", project: project)
        let originalUpdatedAt = link.updatedAt
        try await Task.sleep(nanoseconds: 1_000_000)
        link.label = "GitHub Pro"
        link.url = "https://github.com/pro"
        try linkRepo.update(link)
        #expect(link.updatedAt > originalUpdatedAt)
    }

    @Test("update throws invalidLabel for empty label")
    func updateInvalidLabel() throws {
        let project = try makeProject()
        let link = try linkRepo.create(label: "GitHub", url: "https://github.com", project: project)
        link.label = ""
        #expect(throws: QuickLinkError.invalidLabel) {
            try linkRepo.update(link)
        }
    }

    @Test("delete removes the link")
    func deleteRemovesLink() throws {
        let project = try makeProject()
        let link = try linkRepo.create(label: "GitHub", url: "https://github.com", project: project)
        try linkRepo.delete(link)
        let remaining = try linkRepo.findByProject(project)
        #expect(remaining.isEmpty)
    }

    @Test("cascade delete: deleting a project removes its quick links")
    func cascadeDelete() throws {
        let project = try makeProject()
        _ = try linkRepo.create(label: "A", url: "https://a.com", project: project)
        _ = try linkRepo.create(label: "B", url: "https://b.com", project: project)
        try projectRepo.delete(project)
        let descriptor = FetchDescriptor<QuickLink>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.isEmpty)
    }

    @Test("normalizeURL helper handles edge cases")
    func normalizeURLHelper() {
        #expect(normalizeURL("github.com") == "https://github.com")
        #expect(normalizeURL("https://github.com") == "https://github.com")
        #expect(normalizeURL("http://github.com") == "http://github.com")
        #expect(normalizeURL("  github.com  ") == "https://github.com")
        #expect(normalizeURL("") == nil)
        #expect(normalizeURL("   ") == nil)
    }
}
