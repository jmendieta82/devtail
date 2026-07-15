//
//  WorkspaceSessionClockTests.swift
//  DevtailTests
//
//  Pure formatter tests for the workspace session "elapsed time" card.
//

import Foundation
import Testing
@testable import Devtail

struct WorkspaceSessionClockTests {
    let start = Date(timeIntervalSince1970: 1_000_000)

    @Test func underOneMinuteShowsLessThanOne() {
        #expect(WorkspaceSessionClock.elapsedLabel(from: start, to: start.addingTimeInterval(59)) == "<1m")
    }

    @Test func minutesOnly() {
        #expect(WorkspaceSessionClock.elapsedLabel(from: start, to: start.addingTimeInterval(12 * 60)) == "12m")
    }

    @Test func hoursAndMinutesPadded() {
        #expect(WorkspaceSessionClock.elapsedLabel(from: start, to: start.addingTimeInterval(3_600 + 5 * 60)) == "1h 05m")
    }

    @Test func manyHoursDoNotRollOverToDays() {
        #expect(WorkspaceSessionClock.elapsedLabel(from: start, to: start.addingTimeInterval(26 * 3_600 + 10 * 60)) == "26h 10m")
    }

    @Test func futureStartClampsToZero() {
        #expect(WorkspaceSessionClock.elapsedLabel(from: start, to: start.addingTimeInterval(-30)) == "<1m")
    }
}
