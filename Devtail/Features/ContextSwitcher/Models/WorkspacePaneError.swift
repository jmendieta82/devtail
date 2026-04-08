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
}
