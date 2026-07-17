//
//  ProcessSupervisor.swift
//  Devtail
//
//  Owns the lifecycle of a workspace's managed processes. Every process runs
//  in its own read-only PTY session ("everything is a PTY"): ANSI-colored,
//  scrollback-capable logs for free, and dev servers see a real TTY so they
//  don't buffer. Sessions are retained here — the UI only shows/hides views.
//

import Foundation
import os.log

@Observable
final class ProcessSupervisor {
    private let engine: TerminalEngine
    private let browserLauncher: BrowserLauncherProtocol

    private(set) var processes: [ManagedProcess] = []

    init(engine: TerminalEngine, browserLauncher: BrowserLauncherProtocol) {
        self.engine = engine
        self.browserLauncher = browserLauncher
    }

    /// Build the process list from the project's panes (persisted definitions),
    /// sorted by `order`. `layoutSlot` and the old layout topology are ignored —
    /// this is the v1 migration semantics for legacy projects. See
    /// `activePanes(from:)` for how blank-command panes are filtered out.
    func configure(panes: [WorkspacePane], root: URL) {
        shutdownAll()
        processes = Self.activePanes(from: panes)
            .map { ManagedProcess(pane: $0, root: root) }
    }

    /// Incremental re-sync after a settings edit: surviving panes keep their
    /// ManagedProcess (and live session) by pane id, removed panes are
    /// closed, new panes appear as stopped cards. Never auto-starts anything.
    func reconfigure(panes: [WorkspacePane], root: URL) {
        let incoming = Self.activePanes(from: panes)
        let incomingIds = Set(incoming.map(\.id))

        for process in processes where !incomingIds.contains(process.id) {
            close(process)
        }

        let existing = Dictionary(uniqueKeysWithValues: processes.map { ($0.id, $0) })
        processes = incoming.map { pane in
            if let current = existing[pane.id] {
                current.apply(pane: pane, root: root)
                return current
            }
            return ManagedProcess(pane: pane, root: root)
        }
    }

    /// Blank (or whitespace-only) command panes are placeholders, not
    /// processes — e.g. today's seed default, or a legacy "claude" pane
    /// retired by LegacyClaudePaneMigration — so they never spawn a session.
    /// Shared by `configure` and `reconfigure` to keep filter/sort in sync.
    private static func activePanes(from panes: [WorkspacePane]) -> [WorkspacePane] {
        panes
            .filter { !$0.command.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.order < $1.order }
    }

    func startAll() {
        for process in processes { start(process) }
    }

    func start(_ process: ManagedProcess) {
        guard process.state != .running, process.state != .starting else { return }
        Log.lifecycle.debug("Process start: \(process.name, privacy: .public) (\(process.id.uuidString, privacy: .public))")
        process.state = .starting
        let session = engine.makeSession(
            TerminalSessionConfig(command: process.command, cwd: process.cwd, readOnly: true)
        )
        // Two races guarded here: (1) identity — restart() may have replaced
        // process.session with a fresh one by the time this OLD session's
        // child actually dies (termination is async), so we must confirm
        // process.session is STILL this session before touching state;
        // (2) state — stop() marks .stopped synchronously but does not nil
        // the session, so a late exit after a plain stop passes the identity
        // check and needs the state guard to be rejected.
        session.onExit = { [weak process, weak session] code in
            guard let process, let session,
                  process.session === session,
                  process.state == .running || process.state == .starting else { return }
            process.state = .exited(code)
        }
        process.session = session
        session.start()
        process.state = .running

        if process.isFrontend, let url = process.localhostUrl,
           !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            browserLauncher.open(urlString: url)
        }
    }

    func stop(_ process: ManagedProcess) {
        Log.lifecycle.debug("Process stop: \(process.name, privacy: .public) (\(process.id.uuidString, privacy: .public))")
        // Mark stopped FIRST so the PTY's late exit callback can't overwrite
        // an intentional stop with .exited.
        process.state = .stopped
        process.session?.terminate()
    }

    /// Stop + spawn a FRESH session: new PTY, new view, clean scrollback.
    func restart(_ process: ManagedProcess) {
        Log.lifecycle.debug("Process restart: \(process.name, privacy: .public) (\(process.id.uuidString, privacy: .public))")
        stop(process)
        process.session = nil
        start(process)
    }

    /// Terminate and discard the session entirely — unlike `stop`, which
    /// preserves the session (and its scrollback) for later restart/reopen,
    /// `close` drops it so the process tab disappears (WorkspaceRootView only
    /// renders a tab when `process.session != nil`). Mark stopped FIRST, same
    /// discipline as `stop`, so a late/async PTY exit callback can't overwrite
    /// this intentional close with `.exited`.
    func close(_ process: ManagedProcess) {
        Log.lifecycle.debug("Process close: \(process.name, privacy: .public) (\(process.id.uuidString, privacy: .public))")
        process.state = .stopped
        process.session?.terminate()
        process.session = nil
    }

    func shutdownAll() {
        for process in processes { stop(process) }
    }
}
