//
//  DevtailTerminalViewTests.swift
//  DevtailTests
//
//  DevtailTerminalView wraps an AppKit/SwiftTerm view whose interesting
//  behavior (selectionChanged, send) is only reachable through a live,
//  window-bound NSView and real selection state — not practical to drive
//  headless in a unit test. The copy-on-select DECISION is extracted into
//  a pure helper (`DevtailTerminalView.shouldCopy(selection:)`) so that
//  logic is covered without simulating SwiftTerm's selection machinery.
//  Read-only input-swallowing regression is already covered by the
//  existing ProcessSupervisor tests (ReadOnlyLocalProcessTerminalView keeps
//  its own `send` override that never calls super) — not duplicated here.
//

import Testing
@testable import Devtail

@Suite("DevtailTerminalView")
struct DevtailTerminalViewTests {

    @Test("shouldCopy is false when copyOnSelect is disabled, even with a selection")
    func shouldCopyFalseWhenDisabled() {
        #expect(DevtailTerminalView.shouldCopy(copyOnSelect: false, selection: "hello") == false)
    }

    @Test("shouldCopy is false when there is no active selection")
    func shouldCopyFalseWhenSelectionNil() {
        #expect(DevtailTerminalView.shouldCopy(copyOnSelect: true, selection: nil) == false)
    }

    @Test("shouldCopy is false when the selection is empty")
    func shouldCopyFalseWhenSelectionEmpty() {
        #expect(DevtailTerminalView.shouldCopy(copyOnSelect: true, selection: "") == false)
    }

    @Test("shouldCopy is true when copyOnSelect is enabled and selection is non-empty")
    func shouldCopyTrueWhenEnabledAndNonEmpty() {
        #expect(DevtailTerminalView.shouldCopy(copyOnSelect: true, selection: "hello") == true)
    }
}
