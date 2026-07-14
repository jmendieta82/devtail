//
//  MockVSCodeLauncher.swift
//  DevtailTests
//
//  Test double for VSCodeLauncherProtocol.
//

import Foundation
@testable import Devtail

@MainActor
final class MockVSCodeLauncher: VSCodeLauncherProtocol {
    var openCallCount: Int = 0
    var lastDirectoryPath: String?
    var lastBookmark: Data?
    var errorToThrow: Error?

    func open(directoryPath: String, bookmark: Data?) async throws {
        openCallCount += 1
        lastDirectoryPath = directoryPath
        lastBookmark = bookmark
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
