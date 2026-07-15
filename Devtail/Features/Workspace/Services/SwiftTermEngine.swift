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
//  `nest --watch` children included. SIGTERM first, SIGKILL after a 3s grace.
//

import AppKit
import SwiftTerm

final class SwiftTermEngine: TerminalEngine {
    func makeSession(_ config: TerminalSessionConfig) -> TerminalSession {
        SwiftTermSession(config: config)
    }
}

final class SwiftTermSession: NSObject, TerminalSession, LocalProcessTerminalViewDelegate {
    private let config: TerminalSessionConfig
    private let terminalView: LocalProcessTerminalView
    private var exited = false

    var onExit: ((Int32?) -> Void)?
    var view: NSView { terminalView }

    init(config: TerminalSessionConfig) {
        self.config = config
        self.terminalView = config.readOnly
            ? ReadOnlyLocalProcessTerminalView(frame: .zero)
            : LocalProcessTerminalView(frame: .zero)
        super.init()
        terminalView.processDelegate = self
    }

    func start() {
        let shell = ShellCommand.userShell()
        let invocation = ShellCommand.loginShellInvocation(command: config.command, shell: shell)
        terminalView.startProcess(
            executable: invocation[0],
            args: Array(invocation.dropFirst()),
            environment: Terminal.getEnvironmentVariables(termName: "xterm-256color"),
            execName: nil,
            currentDirectory: config.cwd.path
        )
    }

    func terminate() {
        guard !exited else { return }
        let pid = terminalView.process.shellPid
        guard pid > 0 else { return }
        killpg(pid, SIGTERM)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, !self.exited else { return }
            killpg(pid, SIGKILL)
        }
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
final class ReadOnlyLocalProcessTerminalView: LocalProcessTerminalView {
    override func send(source: TerminalView, data: ArraySlice<UInt8>) { /* read-only: swallow */ }
}
