//
//  MockTerminalEngine.swift
//  DevtailTests
//
//  Test doubles for ProcessSupervisorTests. Reuses the shared
//  MockBrowserLauncher from DevtailTests/Core/Shell (BrowserLauncherProtocol
//  already has a project-wide test double there) rather than redeclaring it.
//

import AppKit
@testable import Devtail

final class MockTerminalSession: TerminalSession {
    let view = NSView()
    var onExit: ((Int32?) -> Void)?
    private(set) var startCount = 0
    private(set) var terminateCount = 0
    private(set) var forceKillCount = 0
    private(set) var written: [String] = []
    private(set) var bracketedWrites: [String] = []

    func start() { startCount += 1 }
    func terminate() { terminateCount += 1 }
    func forceKill() { forceKillCount += 1 }
    func writeToStdin(_ text: String) { written.append(text) }
    func sendBracketedText(_ text: String) { bracketedWrites.append(text) }
    /// Test hook: simulate the PTY child dying.
    func simulateExit(code: Int32?) { onExit?(code) }
}

final class MockTerminalEngine: TerminalEngine {
    private(set) var sessions: [MockTerminalSession] = []
    private(set) var configs: [TerminalSessionConfig] = []

    func makeSession(_ config: TerminalSessionConfig) -> TerminalSession {
        let session = MockTerminalSession()
        sessions.append(session)
        configs.append(config)
        return session
    }
}
