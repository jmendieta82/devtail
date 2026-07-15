//
//  TerminalEngine.swift
//  Devtail
//
//  Emulator abstraction. Consumers (interactive terminal, ProcessSupervisor)
//  talk to these protocols only — never to SwiftTerm directly — so the engine
//  can be mocked in tests and swapped (libghostty) without touching callers.
//

import AppKit

struct TerminalSessionConfig {
    /// Command to run via the login shell; nil/blank = plain interactive shell.
    let command: String?
    /// Working directory for the session.
    let cwd: URL
    /// Read-only sessions render output but swallow keyboard input (process logs).
    let readOnly: Bool
}

@MainActor
protocol TerminalSession: AnyObject {
    /// The emulator's NSView. Retained by the owner; SwiftUI only shows/hides it.
    var view: NSView { get }
    /// Fired once when the session's process exits (code nil if unknown).
    var onExit: ((Int32?) -> Void)? { get set }
    /// Spawn the PTY child (process-group leader) and start emulation.
    func start()
    /// killpg(SIGTERM) → grace → killpg(SIGKILL). Idempotent.
    func terminate()
    /// Forward text to the session's stdin. Interactive sessions only:
    /// on read-only sessions this is a documented no-op (the read-only
    /// swallow intercepts the same delegate funnel keyboard input uses).
    func writeToStdin(_ text: String)
}

@MainActor
protocol TerminalEngine: AnyObject {
    func makeSession(_ config: TerminalSessionConfig) -> TerminalSession
}
