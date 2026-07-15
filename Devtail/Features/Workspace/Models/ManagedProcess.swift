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
    let name: String
    let command: String
    let cwd: URL
    let isFrontend: Bool
    let localhostUrl: String?

    var state: ProcessRunState = .stopped
    /// The live PTY session (also the log view's source). Replaced on restart.
    var session: TerminalSession?

    init(pane: WorkspacePane, root: URL) {
        self.id = pane.id
        self.name = pane.label
        self.command = pane.command
        self.isFrontend = pane.isFrontend
        self.localhostUrl = pane.localhostUrl
        let folder = pane.relativeCwd.trimmingCharacters(in: .whitespacesAndNewlines)
        self.cwd = (folder.isEmpty || folder == ".")
            ? root
            : root.appendingPathComponent(
                folder.hasPrefix("./") ? String(folder.dropFirst(2)) : folder,
                isDirectory: true
            )
    }
}
