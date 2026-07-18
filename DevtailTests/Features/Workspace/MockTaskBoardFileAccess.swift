//
//  MockTaskBoardFileAccess.swift
//  DevtailTests
//
//  In-memory file double for TaskBoardStore tests: a [URL: String] dict
//  plus per-operation failure switches and an optional read delay for
//  cancellation tests.
//

import Foundation
@testable import Devtail

final class MockTaskBoardFileAccess: TaskBoardFileAccessing, @unchecked Sendable {
    var files: [URL: String] = [:]
    var failWrites = false
    var failAppends = false
    var readDelayNanoseconds: UInt64 = 0
    /// Delay before append returns — holds an archive's I/O in flight so
    /// tests can interleave a mutation behind it.
    var appendDelayNanoseconds: UInt64 = 0

    func read(at url: URL) async -> String? {
        if readDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: readDelayNanoseconds)
        }
        return files[url]
    }

    func write(_ text: String, to url: URL) async -> Bool {
        guard !failWrites else { return false }
        files[url] = text
        return true
    }

    func append(_ text: String, to url: URL) async -> Bool {
        if appendDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: appendDelayNanoseconds)
        }
        guard !failAppends else { return false }
        files[url] = (files[url] ?? "") + text
        return true
    }
}
