//
//  WorkspaceTab.swift
//  Devtail
//

import Foundation

/// Identity of a center-column tab in the workspace window.
enum WorkspaceTab: Hashable {
    case terminal
    case process(UUID)
    /// Absolute path of an open file (read-only viewer tab).
    case file(String)
    /// First-class interactive agent tab (auto-launched agent command).
    /// Parameterized by AgentInstance id — a project can run several.
    case agent(UUID)
    /// Project settings form, rendered as a center tab. Stays in the tab row
    /// once opened (`WorkspaceSession.isSettingsTabOpen`) until its own X.
    case settings
    /// Trello-style task board, rendered as a center tab. Stays in the tab row
    /// once opened (`WorkspaceSession.isTasksTabOpen`) until its own X.
    case tasks
}
