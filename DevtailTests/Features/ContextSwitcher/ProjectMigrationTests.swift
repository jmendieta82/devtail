//
//  ProjectMigrationTests.swift
//  DevtailTests
//
//  Lightweight migration smoke test for the launchTargetRaw field added
//  to Project. Verifies that a Project constructed via the existing
//  initializer (no explicit launchTargetRaw argument) resolves to .auto.
//
//  NOTE: This is a BEHAVIOURAL test only. SwiftData's own lightweight
//  migration (adding a String field with a default value) is a framework
//  responsibility and is not exercised here. These tests assert that the
//  Swift default is correct and that the computed accessor works as
//  expected for rows that were never given an explicit launchTargetRaw.
//

import Testing
import Foundation
@testable import Devtail

@MainActor
@Suite("Project — launchTarget lightweight migration defaults")
struct ProjectMigrationTests {

    @Test("Project constructed via legacy init (no explicit launchTargetRaw) defaults to .auto")
    func legacyInitDefaultsToAuto() {
        // This is the existing initializer signature — launchTargetRaw is not
        // exposed as a parameter, so all legacy rows receive the Swift default
        // "auto" when the column is added by SwiftData lightweight migration.
        let project = Project(name: "Legacy Project")
        #expect(project.launchTarget == .auto)
    }

    @Test("launchTargetRaw defaults to LaunchTarget.auto.rawValue")
    func rawValueDefaultIsAuto() {
        let project = Project(name: "Raw Check")
        #expect(project.launchTargetRaw == LaunchTarget.auto.rawValue)
    }

    @Test("Setting launchTarget round-trips through launchTargetRaw")
    func launchTargetRoundTrips() {
        let project = Project(name: "Round Trip")
        project.launchTarget = .newWindow
        #expect(project.launchTargetRaw == "newWindow")
        #expect(project.launchTarget == .newWindow)
    }

    @Test("Invalid launchTargetRaw falls back to .auto")
    func invalidRawFallsBackToAuto() {
        let project = Project(name: "Corrupt Row")
        project.launchTargetRaw = "unknownValue"
        #expect(project.launchTarget == .auto)
    }
}
