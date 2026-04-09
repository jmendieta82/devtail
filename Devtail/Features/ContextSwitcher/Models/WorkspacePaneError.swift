//
//  WorkspacePaneError.swift
//  Devtail
//
//  Domain errors for WorkspacePane CRUD operations.
//

import Foundation

enum WorkspacePaneError: Error, Equatable {
    case invalidLabel
    case invalidRelativeCwd
    case invalidSplitDirection
    /// Refused because the pane being deleted is the only one left on
    /// its project. A workspace with zero panes has no anchor — there
    /// is nowhere for the launcher to "land" the user. The product
    /// invariant is "every workspace has at least one pane".
    case cannotDeleteLastPane
}
