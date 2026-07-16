//
//  WorkspaceSettingsTabView.swift
//  Devtail
//
//  Settings as an ephemeral center tab, split into two scopes via a
//  segmented switcher: "Project" reuses ProjectFormView in edit mode
//  (pane edits save straight through the store, so this view watches the
//  panes signature and re-syncs the supervisor incrementally — the open
//  workspace reflects process changes without relaunching); "Application"
//  hosts the app-wide Agent/Terminal settings (AppSettingsPane), the same
//  controls formerly shown in the standalone Settings window.
//

import SwiftUI

private enum SettingsScope: String, CaseIterable, Identifiable {
    case project = "Project"
    case application = "Application"

    var id: String { rawValue }
}

struct WorkspaceSettingsTabView: View {
    @Environment(ProjectStore.self) private var store
    let session: WorkspaceSession
    @State private var isDirty = false
    @State private var scope: SettingsScope = .project

    /// Cap on the form's readable width inside the center column.
    private static let contentMaxWidth: CGFloat = 720

    private var project: Project? {
        store.projects.first { $0.id == session.projectId }
    }

    var body: some View {
        Group {
            if let project {
                VStack(spacing: DevtailTokens.Spacing.gapMedium) {
                    Picker("Settings scope", selection: $scope) {
                        ForEach(SettingsScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: Self.contentMaxWidth)
                    .padding(.horizontal, DevtailTokens.Spacing.dashboardPadding)
                    .padding(.top, DevtailTokens.Spacing.dashboardPadding)

                    switch scope {
                    case .project:
                        // ProjectFormView already wraps its content in its own
                        // ScrollView, so it's mounted directly here (no extra
                        // ScrollView), mirroring how DashboardRootView presents it.
                        ProjectFormView(
                            projectID: project.id,
                            onDismiss: { session.selectedTab = .agent },
                            isDirty: $isDirty
                        )
                        // Readable measure: the center column can span the whole
                        // window, so cap the form's width and center it instead of
                        // letting fields stretch edge to edge.
                        .frame(maxWidth: Self.contentMaxWidth)
                        .padding(.horizontal, DevtailTokens.Spacing.dashboardPadding)
                        .onChange(of: panesSignature(of: project)) {
                            session.supervisor.reconfigure(
                                panes: project.workspacePanes.sorted { $0.order < $1.order },
                                root: session.root
                            )
                        }
                    case .application:
                        AppSettingsPane()
                            .frame(maxWidth: Self.contentMaxWidth)
                            .padding(.horizontal, DevtailTokens.Spacing.dashboardPadding)
                    }
                }
            } else {
                Text("project not found")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DevtailTokens.Colors.appBackground)
    }

    /// Cheap change signature over everything the supervisor cares about.
    private func panesSignature(of project: Project) -> [String] {
        project.workspacePanes
            .sorted { $0.order < $1.order }
            .map { "\($0.id)|\($0.label)|\($0.command)|\($0.relativeCwd)|\($0.isFrontend)|\($0.localhostUrl ?? "")" }
    }
}
