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

    @Test func secondsUnderAMinute() {
        #expect(WorkspaceSessionClock.elapsedLabel(from: start, to: start.addingTimeInterval(5)) == "00:05")
        #expect(WorkspaceSessionClock.elapsedLabel(from: start, to: start.addingTimeInterval(59)) == "00:59")
    }

    @Test func minutesAndSeconds() {
        #expect(WorkspaceSessionClock.elapsedLabel(from: start, to: start.addingTimeInterval(12 * 60 + 7)) == "12:07")
    }

    @Test func hoursMinutesSeconds() {
        #expect(WorkspaceSessionClock.elapsedLabel(from: start, to: start.addingTimeInterval(3_600 + 5 * 60 + 3)) == "1:05:03")
    }

    @Test func manyHoursDoNotRollOverToDays() {
        #expect(WorkspaceSessionClock.elapsedLabel(from: start, to: start.addingTimeInterval(26 * 3_600 + 10 * 60 + 42)) == "26:10:42")
    }

    @Test func futureStartClampsToZero() {
        #expect(WorkspaceSessionClock.elapsedLabel(from: start, to: start.addingTimeInterval(-30)) == "00:00")
    }
}
