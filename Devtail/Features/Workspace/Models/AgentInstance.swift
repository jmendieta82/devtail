//
//  AgentInstance.swift
//  Devtail
//
//  Runtime state of one Claude agent tab. Ephemeral by design (never
//  persisted): mirrors ManagedProcess's shape — an @Observable identity
//  wrapper the UI and holder share, with the session replaced wholesale on
//  restart. No per-tab conversation id: restart-with-context relaunches
//  with plain `--continue`, which resumes the project's most recently
//  active conversation (Claude Code has no per-tab session tracking that
//  survives a session that never produced conversation activity — see
//  agentLaunchCommand's doc comment in WorkspaceSessionsHolder).
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

    init(title: String, session: TerminalSession) {
        self.title = title
        self.session = session
    }
}
