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
}
