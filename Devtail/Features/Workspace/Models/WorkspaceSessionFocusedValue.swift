//
//  WorkspaceSessionFocusedValue.swift
//  Devtail
//
//  Exposes the frontmost workspace window's session to app-level Commands.
//

import SwiftUI

extension FocusedValues {
    @Entry var workspaceSession: WorkspaceSession?
}
