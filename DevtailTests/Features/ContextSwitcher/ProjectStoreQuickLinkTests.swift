//
//  ProjectStoreQuickLinkTests.swift
//  DevtailTests
//
//  Unit tests for ProjectStore's QuickLink operations (addQuickLink,
//  updateQuickLink, deleteQuickLink) using both mock repositories.
//

import Foundation
import Testing
@testable import Devtail

@MainActor
@Suite("ProjectStore — QuickLink operations")
struct ProjectStoreQuickLinkTests {

    private func makeStore() -> (ProjectStore, MockProjectRepository, MockQuickLinkRepository) {
        let projectRepo = MockProjectRepository()
        let linkRepo = MockQuickLinkRepository()
        let paneRepo = MockWorkspacePaneRepository()
        let store = ProjectStore(
            repository: projectRepo,
            quickLinkRepository: linkRepo,
            workspacePaneRepository: paneRepo
        )
        return (store, projectRepo, linkRepo)
    }

    @Test("addQuickLink delegates to repository on success")
    func addQuickLinkSuccess() {
        let (store, _, linkRepo) = makeStore()
        let project = Project(name: "Devtail", color: .green, environment: .dev)
        store.addQuickLink(label: "GitHub", url: "https://github.com", to: project)

        #expect(linkRepo.createCallCount == 1)
        #expect(linkRepo.lastCreateLabel == "GitHub")
        #expect(linkRepo.lastCreateURL == "https://github.com")
        #expect(store.lastError == nil)
    }

    @Test("addQuickLink captures error on failure")
    func addQuickLinkError() {
        let (store, _, linkRepo) = makeStore()
        linkRepo.errorToThrow = QuickLinkError.invalidURL
        let project = Project(name: "Devtail", color: .green, environment: .dev)

        store.addQuickLink(label: "GitHub", url: "not a url", to: project)

        #expect(store.lastError as? QuickLinkError == .invalidURL)
    }

    @Test("updateQuickLink delegates and clears error on success")
    func updateQuickLinkSuccess() {
        let (store, _, linkRepo) = makeStore()
        let project = Project(name: "Devtail", color: .green, environment: .dev)
        let link = QuickLink(label: "GitHub", url: "https://github.com", order: 0, project: project)

        store.updateQuickLink(link, label: "GitHub Pro", url: "https://github.com/pro")

        #expect(linkRepo.updateCallCount == 1)
        #expect(link.label == "GitHub Pro")
        #expect(link.url == "https://github.com/pro")
        #expect(store.lastError == nil)
    }

    @Test("updateQuickLink captures error on failure")
    func updateQuickLinkError() {
        let (store, _, linkRepo) = makeStore()
        linkRepo.errorToThrow = QuickLinkError.invalidLabel
        let project = Project(name: "Devtail", color: .green, environment: .dev)
        let link = QuickLink(label: "GitHub", url: "https://github.com", order: 0, project: project)

        store.updateQuickLink(link, label: "", url: "https://github.com")

        #expect(store.lastError as? QuickLinkError == .invalidLabel)
    }

    @Test("deleteQuickLink delegates to repository")
    func deleteQuickLinkSuccess() {
        let (store, _, linkRepo) = makeStore()
        let project = Project(name: "Devtail", color: .green, environment: .dev)
        let link = QuickLink(label: "GitHub", url: "https://github.com", order: 0, project: project)

        store.deleteQuickLink(link)

        #expect(linkRepo.deleteCallCount == 1)
        #expect(linkRepo.lastDeletedLink === link)
        #expect(store.lastError == nil)
    }

    @Test("deleteQuickLink captures error on failure")
    func deleteQuickLinkError() {
        let (store, _, linkRepo) = makeStore()
        linkRepo.errorToThrow = QuickLinkError.invalidURL
        let project = Project(name: "Devtail", color: .green, environment: .dev)
        let link = QuickLink(label: "GitHub", url: "https://github.com", order: 0, project: project)

        store.deleteQuickLink(link)

        #expect(store.lastError as? QuickLinkError == .invalidURL)
    }
}
