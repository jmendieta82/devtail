//
//  QuickLinkModelTests.swift
//  DevtailTests
//
//  Tests for the QuickLink SwiftData model.
//

import Foundation
import Testing
import SwiftData
@testable import Devtail

@MainActor
@Suite("QuickLink model")
struct QuickLinkModelTests {

    @Test("init assigns all fields")
    func initAssignsFields() {
        let project = Project(name: "Devtail", color: .green, environment: .dev)
        let link = QuickLink(label: "GitHub", url: "https://github.com", order: 0, project: project)

        #expect(link.label == "GitHub")
        #expect(link.url == "https://github.com")
        #expect(link.order == 0)
        #expect(link.project?.id == project.id)
    }

    @Test("init generates unique id")
    func initGeneratesUniqueID() {
        let project = Project(name: "Devtail", color: .green, environment: .dev)
        let a = QuickLink(label: "A", url: "https://a.com", order: 0, project: project)
        let b = QuickLink(label: "B", url: "https://b.com", order: 1, project: project)
        #expect(a.id != b.id)
    }

    @Test("init sets createdAt and updatedAt to the same instant")
    func initTimestamps() {
        let project = Project(name: "Devtail", color: .green, environment: .dev)
        let link = QuickLink(label: "GitHub", url: "https://github.com", order: 0, project: project)
        #expect(link.createdAt == link.updatedAt)
    }
}
