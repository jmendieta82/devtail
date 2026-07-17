//
//  SwiftTermEngine.swift
//  Devtail
//
//  TerminalEngine adapter over SwiftTerm. Kept deliberately thin: every
//  behavioral decision (spawn shape, kill semantics) lives here so a future
//  libghostty engine replaces ONLY this file.
//
//  Kill semantics: forkpty's child calls setsid, so the shell is a
//  process-group leader and killpg(shellPid, …) reaches the whole tree —
//  `nest --watch` children included. SIGTERM first, SIGKILL after a 3s grace
//  (the staged policy itself lives in ProcessTeardown).
//

import AppKit
import SwiftTerm

final class SwiftTermEngine: TerminalEngine {
    /// Resolves the appearance to apply at first paint (see `SwiftTermSession.init`).
    /// Defaults to `.fallback` so test/mock call sites that construct this
    /// engine directly (no real `AppSettings` around) still compile.
    let appearanceProvider: @MainActor () -> TerminalAppearance

    init(appearanceProvider: @MainActor @escaping () -> TerminalAppearance = { .fallback }) {
        self.appearanceProvider = appearanceProvider
    }

    func makeSession(_ config: TerminalSessionConfig) -> TerminalSession {
        SwiftTermSession(config: config, appearance: appearanceProvider())
    }
}

final class SwiftTermSession: NSObject, TerminalSession, LocalProcessTerminalViewDelegate {
    private let config: TerminalSessionConfig
    private let terminalView: LocalProcessTerminalView
    private let teardown: ProcessTeardown
    private var exited = false

    var onExit: ((Int32?) -> Void)?
    var view: NSView { terminalView }

    init(config: TerminalSessionConfig, appearance: TerminalAppearance,
         teardown: ProcessTeardown = .production) {
        self.config = config
        self.teardown = teardown
        if config.readOnly {
            self.terminalView = ReadOnlyLocalProcessTerminalView(frame: .zero)
        } else if config.imagePaste {
            self.terminalView = AgentTerminalView(frame: .zero)
        } else {
            self.terminalView = DevtailTerminalView(frame: .zero)
        }
        super.init()
        terminalView.processDelegate = self
        appearance.apply(to: terminalView)
    }

    func start() {
        let shell = ShellCommand.userShell()
        let invocation = ShellCommand.loginShellInvocation(command: config.command, shell: shell)
        terminalView.startProcess(
            executable: invocation[0],
            args: Array(invocation.dropFirst()),
            environment: ShellCommand.sessionEnvironment(),
            execName: nil,
            currentDirectory: config.cwd.path
        )
    }

    func terminate() {
        (terminalView as? AgentTerminalView)?.cleanupImages()
        guard !exited else { return }
        let pid = terminalView.process.shellPid
        guard pid > 0 else { return }
        // `self?.exited ?? true`: a deallocated session can't confirm the
        // child is alive, so the escalation is skipped — same behavior as
        // the old inline `[weak self]` block.
        teardown.terminate(group: pid) { [weak self] in self?.exited ?? true }
    }

    func forceKill() {
        guard !exited else { return }
        let pid = terminalView.process.shellPid
        guard pid > 0 else { return }
        teardown.kill(group: pid)
    }

    func writeToStdin(_ text: String) {
        terminalView.send(txt: text)
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        exited = true
        onExit?(exitCode)
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}

/// A terminal view that renders output but swallows all keyboard input —
/// process logs are observable, not typable.
///
/// `MacTerminalView.keyDown(with:)` is `public`, not `open`, so it cannot be
/// overridden outside the SwiftTerm module in this resolved version. Every
/// keyboard path in `keyDown` (typed text via `insertText`, arrows, control
/// sequences, function keys) funnels through the single `open` choke point
/// `LocalProcessTerminalView.send(source:data:)` before reaching the PTY, so
/// swallowing input there is equivalent and leaves `keyDown`'s UI bookkeeping
/// (selection, scrolling) intact.
///
/// NOTE: the same funnel carries programmatic writes — `send(txt:)` and thus
/// the adapter's `writeToStdin` are ALSO no-ops on read-only sessions. This
/// is the documented `TerminalSession.writeToStdin` contract; consumers that
/// need to type into a session must create it with `readOnly: false`.
///
/// Extends `DevtailTerminalView` (not `LocalProcessTerminalView` directly) so
/// it inherits the appearance applier's theme/font/cursor handling, but its
/// `send` override below intentionally does NOT call `super.send` — the
/// mouse-hide-while-typing behavior lives in `DevtailTerminalView.send` and
/// is therefore never reached here. Read-only terminals stay visually
/// themed but never hide the mouse: acceptable per the appearance plan,
/// since there's no typing to hide it from.
final class ReadOnlyLocalProcessTerminalView: DevtailTerminalView {
    override func send(source: TerminalView, data: ArraySlice<UInt8>) { /* read-only: swallow */ }
}
