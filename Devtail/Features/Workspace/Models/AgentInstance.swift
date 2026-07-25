//
//  AgentInstance.swift
//  Devtail
//
//  Runtime state of one Claude agent tab. Ephemeral by design (never
//  persisted): mirrors ManagedProcess's shape — an @Observable identity
//  wrapper the UI and holder share, with the session replaced wholesale on
//  restart. `claudeSessionId` is OUR generated conversation id, handed to
//  the CLI via --session-id so restart-with-context can --resume exactly
//  this tab's conversation (--continue is ambiguous with N tabs in one cwd).
//

import Foundation

@Observable
final class AgentInstance: Identifiable {
    let id = UUID()
    let title: String
    /// The live PTY session. Replaced wholesale on restart, never mutated.
    var session: TerminalSession
    /// Set when the agent process exits. No auto-respawn — drives the
    /// dead-state overlay only.
    var exited = false
    /// The Claude conversation id this tab launched with. Stable across
    /// restart-with-context; rotated by plain restart (fresh conversation).
    private(set) var claudeSessionId: UUID

    init(title: String, session: TerminalSession, claudeSessionId: UUID) {
        self.title = title
        self.session = session
        self.claudeSessionId = claudeSessionId
    }

    /// Fresh conversation id for a plain (non-resume) restart.
    func rotateClaudeSessionId() -> UUID {
        claudeSessionId = UUID()
        return claudeSessionId
    }
}
