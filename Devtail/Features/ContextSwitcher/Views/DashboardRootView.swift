//
//  DashboardRootView.swift
//  Devtail
//
//  Root view of the desktop dashboard window (Docker Desktop-style).
//  Placeholder — Phase 1 will add the sidebar, project detail, and tabs.
//

import SwiftUI

struct DashboardRootView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Text("Projects")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            ContentUnavailableView(
                "Select a project",
                systemImage: "folder",
                description: Text("Pick a project from the sidebar to see its details.")
            )
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

#Preview {
    DashboardRootView()
}
