//
//  MockClaudeIntrospector.swift
//  DevtailTests
//
//  Test double for ClaudeIntrospecting. Lets WorkspaceSession claude-info
//  wiring be exercised (assign-on-success, no-assign-when-cancelled)
//  without touching the real filesystem.
//

import Foundation
@testable import Devtail

final class MockClaudeIntrospector: ClaudeIntrospecting, @unchecked Sendable {
    var resultToReturn: ClaudeIntrospection
    /// Optional delay before returning, so tests can cancel the refresh
    /// task while the read is still "in flight".
    var delayNanoseconds: UInt64 = 0
    private(set) var callCount = 0

    init(resultToReturn: ClaudeIntrospection = .empty) {
        self.resultToReturn = resultToReturn
    }

    func introspect(projectRoot: URL, home: URL) async -> ClaudeIntrospection {
        callCount += 1
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return resultToReturn
    }
}
