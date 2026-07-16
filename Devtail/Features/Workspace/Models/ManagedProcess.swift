//
//  ManagedProcess.swift
//  Devtail
//
//  Runtime state of one managed dev-server process. Built FROM a
//  WorkspacePane (the persisted definition) — panes are reinterpreted as
//  process definitions in v1; layoutSlot and friends are ignored.
//  Not a SwiftData model: run state is ephemeral by design.
//

import Foundation

enum ProcessRunState: Equatable {
    case stopped
    case starting
    case running
    case exited(Int32?)
}

@Observable
final class ManagedProcess: Identifiable {
    let id: UUID
    private(set) var name: String
    private(set) var command: String
    private(set) var cwd: URL
    private(set) var isFrontend: Bool
    private(set) var localhostUrl: String?

    var state: ProcessRunState = .stopped
    /// The live PTY session (also the log view's source). Replaced on restart.
    var session: TerminalSession?

    init(pane: WorkspacePane, root: URL) {
        self.id = pane.id
        self.name = pane.label
        self.command = pane.command
        self.isFrontend = pane.isFrontend
        self.localhostUrl = pane.localhostUrl
        self.cwd = Self.resolveCwd(relativeCwd: pane.relativeCwd, root: root)
    }

    /// Refreshes the pane-derived fields after a settings edit. The live
    /// session (if any) keeps running its already-spawned command; the new
    /// command takes effect on the next start/restart.
    func apply(pane: WorkspacePane, root: URL) {
        name = pane.label
        command = pane.command
        cwd = Self.resolveCwd(relativeCwd: pane.relativeCwd, root: root)
        isFrontend = pane.isFrontend
        localhostUrl = pane.localhostUrl
    }

    private static func resolveCwd(relativeCwd: String, root: URL) -> URL {
        let folder = relativeCwd.trimmingCharacters(in: .whitespacesAndNewlines)
        return (folder.isEmpty || folder == ".")
            ? root
            : root.appendingPathComponent(
                folder.hasPrefix("./") ? String(folder.dropFirst(2)) : folder,
                isDirectory: true
            )
    }
}
