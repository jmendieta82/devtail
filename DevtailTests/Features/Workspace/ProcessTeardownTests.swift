//
//  ProcessTeardownTests.swift
//  DevtailTests
//
//  The staged-kill policy in isolation: a signal spy replaces killpg and a
//  manually fired scheduler replaces the main-queue grace deadline, so the
//  SIGTERM -> grace -> SIGKILL sequence is asserted deterministically.
//

import Foundation
import Testing
@testable import Devtail

@MainActor
struct ProcessTeardownTests {
    /// Records delivered signals and captures scheduled blocks;
    /// `fireScheduled()` runs them synchronously — the test controls time.
    @MainActor
    final class Harness {
        private(set) var signals: [(pid: pid_t, signal: Int32)] = []
        private(set) var delays: [TimeInterval] = []
        private var blocks: [@MainActor () -> Void] = []
        var signalResult: Int32 = 0

        func makeTeardown() -> ProcessTeardown {
            ProcessTeardown(
                signal: { pid, sig in
                    self.signals.append((pid, sig))
                    return self.signalResult
                },
                schedule: { delay, block in
                    self.delays.append(delay)
                    self.blocks.append(block)
                }
            )
        }

        func fireScheduled() {
            let pending = blocks
            blocks = []
            for block in pending { block() }
        }
    }

    @Test func sendsSigtermToGroupImmediately() {
        let harness = Harness()

        harness.makeTeardown().terminate(group: 1234) { false }

        #expect(harness.signals.count == 1)
        #expect(harness.signals[0].pid == 1234)
        #expect(harness.signals[0].signal == SIGTERM)
    }

    @Test func escalatesToSigkillAfterGrace() {
        let harness = Harness()

        harness.makeTeardown().terminate(group: 1234) { false }
        #expect(harness.delays == [ProcessTeardown.grace])
        #expect(harness.signals.map(\.signal) == [SIGTERM])

        harness.fireScheduled()

        #expect(harness.signals.map(\.signal) == [SIGTERM, SIGKILL])
        #expect(harness.signals.last?.pid == 1234)
    }

    @Test func skipsSigkillWhenProcessExitedDuringGrace() {
        let harness = Harness()
        var exited = false

        harness.makeTeardown().terminate(group: 1234) { exited }
        exited = true
        harness.fireScheduled()

        #expect(harness.signals.map(\.signal) == [SIGTERM])
    }

    @Test func failedSigtermStillSchedulesEscalation() {
        let harness = Harness()
        harness.signalResult = -1

        harness.makeTeardown().terminate(group: 1234) { false }

        // Non-zero killpg is logged, never fatal; the SIGKILL backstop
        // still goes out after the grace.
        #expect(harness.delays.count == 1)
        harness.fireScheduled()
        #expect(harness.signals.map(\.signal) == [SIGTERM, SIGKILL])
    }

    @Test func killSendsImmediateSigkillWithoutScheduling() {
        let harness = Harness()

        harness.makeTeardown().kill(group: 99)

        #expect(harness.signals.map(\.signal) == [SIGKILL])
        #expect(harness.signals[0].pid == 99)
        #expect(harness.delays.isEmpty)
    }
}
