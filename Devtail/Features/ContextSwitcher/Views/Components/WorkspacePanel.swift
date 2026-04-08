//
//  WorkspacePanel.swift
//  Devtail
//
//  Detail panel for Workspace panes. Shows the pane list for the selected
//  project, edit-mode toggle, inline add/edit rows, and a disabled
//  "Launch" button (Coming soon — launcher ships in Change 2).
//

import SwiftUI
import SwiftData

struct WorkspacePanel: View {
    let projectID: UUID?

    @Environment(ProjectStore.self) private var store

    @State private var isEditingPanes: Bool = false
    @State private var isAddingPane: Bool = false
    @State private var editingPaneID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
        }
        .padding(.horizontal, DevtailTokens.Spacing.popoverPadding)
        .padding(.vertical, DevtailTokens.Spacing.gapMedium)
        .onChange(of: projectID) { _, _ in
            resetEditState()
        }
    }

    // MARK: - Computed helpers

    private var currentProject: Project? {
        guard let projectID else { return nil }
        return store.projects.first { $0.id == projectID }
    }

    private var sortedPanes: [WorkspacePane] {
        currentProject?.workspacePanes.sorted { $0.order < $1.order } ?? []
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            Text("WORKSPACE")
                .font(DevtailTokens.Typography.captionSmall)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
                .tracking(0.5)
            if let count = currentProject?.workspacePanes.count, count > 0 {
                Text("\(count)")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textMuted)
            }
            Spacer()
            Button {
                // Launch Workspace — disabled until Change 2
            } label: {
                HStack(spacing: DevtailTokens.Spacing.gapTiny) {
                    Image(systemName: "play.fill")
                        .font(DevtailTokens.Typography.captionSmall)
                    Text("Launch")
                        .font(DevtailTokens.Typography.bodySmall)
                }
                .foregroundStyle(DevtailTokens.Colors.textDisabled)
            }
            .buttonStyle(.plain)
            .disabled(true)
            .help("Coming soon — workspace launcher")

            if currentProject != nil {
                Button(isEditingPanes ? "Done" : "Edit") {
                    if isEditingPanes {
                        isAddingPane = false
                        editingPaneID = nil
                    }
                    isEditingPanes.toggle()
                }
                .buttonStyle(.plain)
                .font(DevtailTokens.Typography.bodySmall)
                .foregroundStyle(DevtailTokens.Colors.accentGreen)
            }
        }
        .padding(.bottom, DevtailTokens.Spacing.gapMedium)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if currentProject == nil {
            emptyNoSelection
        } else if sortedPanes.isEmpty && !isEditingPanes {
            emptyNoPanes
        } else {
            paneList
        }
    }

    private var emptyNoSelection: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
            Text("Select a project")
                .font(DevtailTokens.Typography.bodyDefault)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Text("Tap a project to see its workspace panes.")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var emptyNoPanes: some View {
        VStack(alignment: .center, spacing: DevtailTokens.Spacing.gapSmall) {
            Text("No panes yet")
                .font(DevtailTokens.Typography.bodyDefault)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Text("Enter edit mode to add your first pane.")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var paneList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
                ForEach(sortedPanes, id: \.id) { pane in
                    if editingPaneID == pane.id {
                        WorkspacePaneEditRow(
                            initialLabel: pane.label,
                            initialRelativeCwd: pane.relativeCwd,
                            initialCommand: pane.command,
                            initialSplitDirection: pane.splitDirection,
                            onSave: { label, cwd, cmd, dir in
                                store.updateWorkspacePane(
                                    pane,
                                    label: label,
                                    relativeCwd: cwd,
                                    command: cmd,
                                    splitDirection: dir
                                )
                                editingPaneID = nil
                            },
                            onCancel: {
                                editingPaneID = nil
                            }
                        )
                    } else {
                        WorkspacePaneRow(
                            pane: pane,
                            isEditing: isEditingPanes,
                            onEditTap: {
                                editingPaneID = pane.id
                            },
                            onDelete: {
                                store.deleteWorkspacePane(pane)
                            }
                        )
                    }
                }

                if isEditingPanes {
                    if isAddingPane {
                        WorkspacePaneEditRow(
                            onSave: { label, cwd, cmd, dir in
                                if let project = currentProject {
                                    store.addWorkspacePane(
                                        label: label,
                                        relativeCwd: cwd,
                                        command: cmd,
                                        splitDirection: dir,
                                        to: project
                                    )
                                }
                                isAddingPane = false
                            },
                            onCancel: {
                                isAddingPane = false
                            }
                        )
                    } else {
                        Button {
                            isAddingPane = true
                        } label: {
                            HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                                Image(systemName: "plus")
                                Text("Add pane")
                            }
                            .font(DevtailTokens.Typography.bodySmall)
                            .foregroundStyle(DevtailTokens.Colors.accentGreen)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func resetEditState() {
        isEditingPanes = false
        isAddingPane = false
        editingPaneID = nil
    }
}

#Preview("No selection") {
    let store: ProjectStore = {
        let container = PersistenceController.makeContainer(inMemory: true)
        let projectRepo = ProjectRepository(context: container.mainContext)
        let linkRepo = QuickLinkRepository(context: container.mainContext)
        let paneRepo = WorkspacePaneRepository(context: container.mainContext)
        return ProjectStore(repository: projectRepo, quickLinkRepository: linkRepo, workspacePaneRepository: paneRepo)
    }()
    WorkspacePanel(projectID: nil)
        .environment(store)
        .frame(width: 320, height: DevtailTokens.Sizes.detailPanelHeight)
        .background(DevtailTokens.Colors.popoverBackground)
}

#Preview("With panes") {
    let (store, projectID): (ProjectStore, UUID) = {
        let container = PersistenceController.makeContainer(inMemory: true)
        let projectRepo = ProjectRepository(context: container.mainContext)
        let linkRepo = QuickLinkRepository(context: container.mainContext)
        let paneRepo = WorkspacePaneRepository(context: container.mainContext)
        let store = ProjectStore(repository: projectRepo, quickLinkRepository: linkRepo, workspacePaneRepository: paneRepo)
        store.createProject(name: "Devtail", color: .green, environment: .dev, stack: "Swift")
        return (store, store.projects[0].id)
    }()
    WorkspacePanel(projectID: projectID)
        .environment(store)
        .frame(width: 320, height: DevtailTokens.Sizes.detailPanelHeight)
        .background(DevtailTokens.Colors.popoverBackground)
}
