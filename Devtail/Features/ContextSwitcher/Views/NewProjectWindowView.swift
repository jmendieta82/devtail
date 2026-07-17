//
//  NewProjectWindowView.swift
//  Devtail
//
//  Minimal window hosting the project creation form. Replaces the
//  dashboard's create flow — opened via Cmd+N or the popover's
//  "New project" actions.
//

import SwiftUI

struct NewProjectWindowView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isFormDirty: Bool = false

    var body: some View {
        ProjectFormView(
            projectID: nil,
            onDismiss: { dismiss() },
            isDirty: $isFormDirty
        )
        .padding(DevtailTokens.Spacing.gapLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(DevtailGradients.appBackground, for: .window)
    }
}
