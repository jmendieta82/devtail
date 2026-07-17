//
//  ProjectSorterTests.swift
//  DevtailTests
//
//  Tests the pure sort function that powers the popover header's sort
//  menu. Ported from the retired dashboard's inline sort — same rules,
//  now locked here.
//

import Testing
import Foundation
@testable import Devtail

@Suite("ProjectSorter")
@MainActor
struct ProjectSorterTests {

    // MARK: - Fixture helpers

    private func makeProjects() -> [Project] {
        let zeta = Project(name: "Zeta", color: .green)
        let alpha = Project(name: "alpha", color: .blue)
        let mango = Project(name: "Mango", color: .purple)
        return [zeta, alpha, mango]
    }

    // MARK: - Alphabetical

    @Test("alphabetical sorts by name case-insensitively ascending")
    func alphabeticalSortsCaseInsensitive() {
        let projects = makeProjects()
        let sorter = ProjectSorter()

        let result = sorter.sort(projects, mode: .alphabetical)

        #expect(result.map(\.name) == ["alpha", "Mango", "Zeta"])
    }

    // MARK: - Recency

    @Test("recency orders most recently launched first")
    func recencyOrdersMostRecentFirst() {
        let older = Project(name: "Older", color: .green)
        older.lastLaunchedAt = Date(timeIntervalSince1970: 1000)
        let newer = Project(name: "Newer", color: .blue)
        newer.lastLaunchedAt = Date(timeIntervalSince1970: 2000)

        let sorter = ProjectSorter()
        let result = sorter.sort([older, newer], mode: .recency)

        #expect(result.map(\.name) == ["Newer", "Older"])
    }

    @Test("recency sinks never-launched projects below launched ones")
    func recencySinksNeverLaunched() {
        let launched = Project(name: "Launched", color: .green)
        launched.lastLaunchedAt = Date(timeIntervalSince1970: 1000)
        let neverLaunched = Project(name: "Fresh", color: .blue)

        let sorter = ProjectSorter()
        let result = sorter.sort([neverLaunched, launched], mode: .recency)

        #expect(result.map(\.name) == ["Launched", "Fresh"])
    }

    @Test("recency sorts never-launched projects alphabetically among themselves")
    func recencySortsNeverLaunchedAlphabetically() {
        let projects = makeProjects() // none have lastLaunchedAt set
        let sorter = ProjectSorter()

        let result = sorter.sort(projects, mode: .recency)

        #expect(result.map(\.name) == ["alpha", "Mango", "Zeta"])
    }

    @Test("empty input stays empty regardless of mode")
    func emptyInputStaysEmpty() {
        let sorter = ProjectSorter()

        #expect(sorter.sort([], mode: .recency).isEmpty)
        #expect(sorter.sort([], mode: .alphabetical).isEmpty)
    }
}
