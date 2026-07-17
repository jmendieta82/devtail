//
//  MockGitStatusReader.swift
//  DevtailTests
//
//  Test double for GitStatusReading. Lets WorkspaceSession git-status wiring
//  be exercised (assign-on-success, no-assign-when-cancelled) without
//  shelling out to a real `git` process.
//

import Foundation
@testable import Devtail

final class MockGitStatusReader: GitStatusReading, @unchecked Sendable {
    var statusToReturn: GitStatus?
    /// Optional delay before returning, so tests can cancel the refresh
    /// task while the read is still "in flight".
    var delayNanoseconds: UInt64 = 0
    private(set) var callCount = 0

    init(statusToReturn: GitStatus? = nil) {
        self.statusToReturn = statusToReturn
    }

    func status(in root: URL) async -> GitStatus? {
        callCount += 1
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return statusToReturn
    }
}
