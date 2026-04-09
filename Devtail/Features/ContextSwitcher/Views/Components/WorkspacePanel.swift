//
//  WorkspacePanel.swift
//  Devtail
//
//  Detail panel for Workspace panes. Lists the panes of the selected
//  project (read-only rows with hover actions for edit/delete), a
//  permanent "+ Add pane" button next to Launch, and an inline editor
//  that takes over when adding or editing a pane.
//
//  The previous "Edit/Done" toggle is gone: panes are always editable
//  via hover actions, and a new pane is always one click away.
//

import SwiftUI
import SwiftData

struct WorkspacePanel: View {
    let projectID: UUID?

    @Environment(ProjectStore.self) private var store

    @State private var editingPaneID: UUID?
    @State private var isAddingPane: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
            if let launcherError = store.lastError as? WorkspaceLauncherError {
                launchErrorBanner(launcherError)
            }
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

    private var projectRoot: String {
        currentProject?.directoryPath ?? ""
    }

    private var hasProjectRoot: Bool {
        !projectRoot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canLaunch: Bool {
        hasProjectRoot && !sortedPanes.isEmpty
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

            // Secondary: add a new pane (icon-only, discreet).
            if currentProject != nil {
                Button {
                    startAddingPane()
                } label: {
                    Image(systemName: "plus")
                        .font(DevtailTokens.Typography.bodySmall)
                        .foregroundStyle(
                            hasProjectRoot
                                ? DevtailTokens.Colors.textSecondary
                                : DevtailTokens.Colors.textDisabled
                        )
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!hasProjectRoot || isAddingPane || editingPaneID != nil)
                .help(
                    hasProjectRoot
                        ? "Add workspace pane"
                        : "Set a project directory first"
                )
            }

            // Keep a visible gap between the secondary (add) and the
            // primary CTA (Launch). A mis-click on Add should NOT fire
            // Launch — Launch actually opens Ghostty and runs commands.
            Spacer()
                .frame(width: DevtailTokens.Spacing.gapLarge)

            // Primary: launch workspace (prominent, green).
            Button {
                guard let project = currentProject else { return }
                store.launchWorkspace(for: project)
            } label: {
                HStack(spacing: DevtailTokens.Spacing.gapTiny) {
                    Image(systemName: store.isLaunchingWorkspace ? "hourglass" : "play.fill")
                        .font(DevtailTokens.Typography.captionSmall)
                    Text(store.isLaunchingWorkspace ? "Launching..." : "Launch")
                        .font(DevtailTokens.Typography.bodySmall)
                }
                .foregroundStyle(
                    canLaunch
                        ? DevtailTokens.Colors.accentGreen
                        : DevtailTokens.Colors.textDisabled
                )
            }
            .buttonStyle(.plain)
            .disabled(!canLaunch || store.isLaunchingWorkspace)
            .help(launchHelp)
        }
        .padding(.bottom, DevtailTokens.Spacing.gapMedium)
    }

    private var launchHelp: String {
        if !hasProjectRoot {
            return "Set a project directory first"
        }
        if sortedPanes.isEmpty {
            return "Add at least one workspace pane first"
        }
        return "Launch workspace in Ghostty"
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if currentProject == nil {
            emptyNoSelection
        } else if !hasProjectRoot && sortedPanes.isEmpty {
            emptyNoProjectRoot
        } else if sortedPanes.isEmpty && !isAddingPane {
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

    private var emptyNoProjectRoot: some View {
        VStack(alignment: .center, spacing: DevtailTokens.Spacing.gapSmall) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
            Text("Set a project directory first")
                .font(DevtailTokens.Typography.bodyDefault)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Text("Edit this project and choose its root folder, then come back to add workspace panes.")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DevtailTokens.Spacing.gapLarge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var emptyNoPanes: some View {
        VStack(alignment: .center, spacing: DevtailTokens.Spacing.gapSmall) {
            Text("No panes yet")
                .font(DevtailTokens.Typography.bodyDefault)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Text("Tap + to add your first pane.")
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
                            projectRoot: projectRoot,
                            initialLabel: pane.label,
                            initialRelativeCwd: pane.relativeCwd,
                            initialCommand: pane.command,
                            initialSplitDirection: pane.splitDirection,
                            initialStack: pane.stack,
                            onSave: { label, cwd, cmd, dir, stack in
                                store.updateWorkspacePane(
                                    pane,
                                    label: label,
                                    relativeCwd: cwd,
                                    command: cmd,
                                    splitDirection: dir,
                                    stack: stack
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
                            onEditTap: { startEditingPane(pane.id) },
                            onDelete: { store.deleteWorkspacePane(pane) }
                        )
                    }
                }

                if isAddingPane {
                    WorkspacePaneEditRow(
                        projectRoot: projectRoot,
                        onSave: { label, cwd, cmd, dir, stack in
                            if let project = currentProject {
                                store.addWorkspacePane(
                                    label: label,
                                    relativeCwd: cwd,
                                    command: cmd,
                                    splitDirection: dir,
                                    stack: stack,
                                    to: project
                                )
                            }
                            isAddingPane = false
                        },
                        onCancel: {
                            isAddingPane = false
                        }
                    )
                }
            }
        }
    }

    // MARK: - Edit state transitions

    private func startAddingPane() {
        guard hasProjectRoot else { return }
        editingPaneID = nil
        isAddingPane = true
    }

    private func startEditingPane(_ id: UUID) {
        guard hasProjectRoot else { return }
        isAddingPane = false
        editingPaneID = id
    }

    private func resetEditState() {
        isAddingPane = false
        editingPaneID = nil
    }

    @ViewBuilder
    private func launchErrorBanner(_ error: WorkspaceLauncherError) -> some View {
        HStack(alignment: .top, spacing: DevtailTokens.Spacing.gapSmall) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DevtailTokens.Typography.captionSmall)
                .foregroundStyle(DevtailTokens.Colors.accentOrange)
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
                switch error {
                case .projectHasNoDirectory:
                    Text("No project directory set.")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textSecondary)
                case .ghosttyNotInstalled:
                    Text("Ghostty not installed.")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textSecondary)
                    Button("Download Ghostty") {
                        if let url = URL(string: "https://ghostty.org") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.accentGreen)
                case .automationPermissionDenied:
                    Text("Automation permission denied.")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textSecondary)
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.accentGreen)
                case .appleScriptFailed(let message):
                    Text("Launch failed: \(message)")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textSecondary)
                        .lineLimit(3)
                }
            }
            Spacer()
        }
        .padding(DevtailTokens.Spacing.gapSmall)
        .background(DevtailTokens.Colors.popoverBackground.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(DevtailTokens.Colors.accentOrange.opacity(0.5), lineWidth: 1)
        )
        .padding(.top, DevtailTokens.Spacing.gapSmall)
    }
}

#Preview("No selection") {
    let store: ProjectStore = {
        let container = PersistenceController.makeContainer(inMemory: true)
        let projectRepo = ProjectRepository(context: container.mainContext)
        let linkRepo = QuickLinkRepository(context: container.mainContext)
        let paneRepo = WorkspacePaneRepository(context: container.mainContext)
        return ProjectStore(
            repository: projectRepo,
            quickLinkRepository: linkRepo,
            workspacePaneRepository: paneRepo,
            launcher: WorkspaceLauncher()
        )
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
        let store = ProjectStore(
            repository: projectRepo,
            quickLinkRepository: linkRepo,
            workspacePaneRepository: paneRepo,
            launcher: WorkspaceLauncher()
        )
        store.createProject(name: "Devtail", color: .green, environment: .dev)
        return (store, store.projects[0].id)
    }()
    WorkspacePanel(projectID: projectID)
        .environment(store)
        .frame(width: 320, height: DevtailTokens.Sizes.detailPanelHeight)
        .background(DevtailTokens.Colors.popoverBackground)
}
