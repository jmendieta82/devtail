//
//  MockWorkspaceLauncher.swift
//  DevtailTests
//
//  Test double for WorkspaceLauncherProtocol used by ProjectStore tests.
//

import Foundation
@testable import Devtail

@MainActor
final class MockWorkspaceLauncher: WorkspaceLauncherProtocol {
    var launchCallCount: Int = 0
    var lastLaunchedProject: Project?
    var lastLaunchedPanes: [WorkspacePane] = []
    var errorToThrow: Error?

    func launch(project: Project, panes: [WorkspacePane]) async throws {
        launchCallCount += 1
        lastLaunchedProject = project
        lastLaunchedPanes = panes
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
