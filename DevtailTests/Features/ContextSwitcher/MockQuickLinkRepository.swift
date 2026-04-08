//
//  MockQuickLinkRepository.swift
//  DevtailTests
//
//  Test double for QuickLinkRepositoryProtocol. Class (not struct) so tests
//  can mutate counters by reference through the same instance held by the store.
//

import Foundation
@testable import Devtail

@MainActor
final class MockQuickLinkRepository: QuickLinkRepositoryProtocol {

    // MARK: - Stub state

    var linkToReturn: QuickLink?
    var linksToReturn: [QuickLink] = []
    var errorToThrow: Error?

    // MARK: - Call counters

    var createCallCount = 0
    var findByProjectCallCount = 0
    var updateCallCount = 0
    var deleteCallCount = 0

    // MARK: - Capture state

    var lastCreateLabel: String?
    var lastCreateURL: String?
    var lastCreateProject: Project?
    var lastUpdatedLink: QuickLink?
    var lastDeletedLink: QuickLink?

    // MARK: - QuickLinkRepositoryProtocol

    func create(label: String, url: String, project: Project) throws -> QuickLink {
        createCallCount += 1
        lastCreateLabel = label
        lastCreateURL = url
        lastCreateProject = project
        if let errorToThrow {
            throw errorToThrow
        }
        if let linkToReturn {
            return linkToReturn
        }
        let link = QuickLink(label: label, url: url, order: 0, project: project)
        return link
    }

    func findByProject(_ project: Project) throws -> [QuickLink] {
        findByProjectCallCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
        return linksToReturn
    }

    func update(_ quickLink: QuickLink) throws {
        updateCallCount += 1
        lastUpdatedLink = quickLink
        if let errorToThrow {
            throw errorToThrow
        }
    }

    func delete(_ quickLink: QuickLink) throws {
        deleteCallCount += 1
        lastDeletedLink = quickLink
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
