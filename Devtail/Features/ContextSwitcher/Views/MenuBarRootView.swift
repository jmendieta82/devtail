//
//  MenuBarRootView.swift
//  Devtail
//
//  Root view rendered inside the MenuBarExtra popover.
//  Placeholder — Phase 1 will replace it with the project list and quick actions.
//

import SwiftUI

struct MenuBarRootView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Devtail")
                .font(.headline)

            Text("No projects yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            Button("Open dashboard") {
                openWindow(id: WindowID.dashboard)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Button("Quit Devtail") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(16)
        .frame(width: 280)
    }
}

#Preview {
    MenuBarRootView()
}
