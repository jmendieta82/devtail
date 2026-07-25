//
//  WorkspaceCommands.swift
//  Devtail
//
//  Workspace keyboard map, mirrored by the Shortcuts card in
//  WorkspaceDashboardColumn (keep in sync). Registered as real menu
//  commands because hidden background buttons are not indexed until first
//  re-render (the launch bug this replaces).
//

import SwiftUI

struct WorkspaceCommands: Commands {
    @FocusedValue(\.workspaceSession) private var session
    /// Restart lives on the holder, not the session — injected from
    /// DevtailApp because focused values only carry the session.
    let holder: WorkspaceSessionsHolder

    var body: some Commands {
        CommandMenu("Workspace") {
            Button("Files") {
                session?.sidePanel = .files
                session?.fileSearch.requestFocus()
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(session == nil)

            Button("Processes") {
                session?.sidePanel = .processes
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(session == nil)

            Button("Terminal") {
                session?.selectedTab = .terminal
            }
            .keyboardShortcut("t", modifiers: .command)
            .disabled(session == nil)

            Button("Task Board") {
                session?.openTasks()
            }
            .keyboardShortcut("b", modifiers: .command)
            .disabled(session == nil)

            Button("Agent") {
                guard let session else { return }
                session.selectedTab = session.firstAgentTab
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            .disabled(session == nil)

            Divider()

            // Cmd+S belongs to Save while a file tab is active — the env
            // editor registers it on its Save button. A disabled menu item
            // does not consume the key equivalent, so disabling this one
            // when a file tab is selected lets the env editor's Save keep
            // Cmd+S in file tabs.
            Button("Settings") {
                session?.openSettings()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(session == nil || isFileTabSelected)

            Divider()

            Button("Toggle Left Panel") {
                session?.sidePanel = session?.sidePanel == nil ? .files : nil
            }
            .keyboardShortcut("i", modifiers: .command)
            .disabled(session == nil)

            Button("Toggle Project Panel") {
                session?.dashboardCollapsed.toggle()
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(session == nil)

            Divider()

            // Always-available escape hatch: works on a live or stuck agent
            // too, not just after exit — restartAgent terminates first.
            // Targets the SELECTED agent tab when one is selected; the
            // first agent otherwise.
            Button("Restart Agent with Context") {
                guard let session else { return }
                var agentId: UUID?
                if case .agent(let id) = session.selectedTab { agentId = id }
                holder.restartAgent(projectId: session.projectId, agentId: agentId, resume: true)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(session == nil)
        }
    }

    private var isFileTabSelected: Bool {
        if case .file = session?.selectedTab { return true }
        return false
    }
}
