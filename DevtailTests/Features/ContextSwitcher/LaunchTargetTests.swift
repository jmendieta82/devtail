//
//  LaunchTargetTests.swift
//  DevtailTests
//
//  Tests for LaunchTarget enum identity, labels, rawValue round-trips,
//  and unknown-value fallback behaviour.
//

import Testing
import Foundation
@testable import Devtail

@Suite("LaunchTarget enum")
struct LaunchTargetTests {

    // MARK: - Labels

    @Test(".auto label is 'Auto (use existing window if any)'")
    func autoLabel() {
        #expect(LaunchTarget.auto.label == "Auto (use existing window if any)")
    }

    @Test(".newTab label is 'New tab'")
    func newTabLabel() {
        #expect(LaunchTarget.newTab.label == "New tab")
    }

    @Test(".newWindow label is 'New window'")
    func newWindowLabel() {
        #expect(LaunchTarget.newWindow.label == "New window")
    }

    // MARK: - rawValue round-trips

    @Test(".auto rawValue is 'auto' and round-trips")
    func autoRawValue() {
        #expect(LaunchTarget.auto.rawValue == "auto")
        #expect(LaunchTarget(rawValue: "auto") == .auto)
    }

    @Test(".newTab rawValue is 'newTab' and round-trips")
    func newTabRawValue() {
        #expect(LaunchTarget.newTab.rawValue == "newTab")
        #expect(LaunchTarget(rawValue: "newTab") == .newTab)
    }

    @Test(".newWindow rawValue is 'newWindow' and round-trips")
    func newWindowRawValue() {
        #expect(LaunchTarget.newWindow.rawValue == "newWindow")
        #expect(LaunchTarget(rawValue: "newWindow") == .newWindow)
    }

    // MARK: - Unknown rawValue fallback

    @Test("Unknown rawValue returns nil from failable init")
    func unknownRawValueIsNil() {
        #expect(LaunchTarget(rawValue: "unknownValue") == nil)
    }

    @Test("Empty string rawValue returns nil from failable init")
    func emptyRawValueIsNil() {
        #expect(LaunchTarget(rawValue: "") == nil)
    }

    // MARK: - CaseIterable

    @Test("allCases contains all three values")
    func allCasesHasThreeEntries() {
        #expect(LaunchTarget.allCases.count == 3)
        #expect(LaunchTarget.allCases.contains(.auto))
        #expect(LaunchTarget.allCases.contains(.newTab))
        #expect(LaunchTarget.allCases.contains(.newWindow))
    }

    // MARK: - Identifiable

    @Test("id equals rawValue")
    func idEqualsRawValue() {
        for target in LaunchTarget.allCases {
            #expect(target.id == target.rawValue)
        }
    }

    // MARK: - Codable

    @Test("Codable round-trip for all cases")
    func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for target in LaunchTarget.allCases {
            let data = try encoder.encode(target)
            let decoded = try decoder.decode(LaunchTarget.self, from: data)
            #expect(decoded == target)
        }
    }
}
