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
    /// When true, the panel renders a stripped-down view: no inline
    /// editor, no add button, no hover actions on rows, no context
    /// menu. The Launch button STAYS — read-only refers to *editing*
    /// the workspace configuration, not to disabling the action that
    /// makes the popover useful in the first place.
    var isReadOnly: Bool = false

    @Environment(ProjectStore.self) private var store

    @State private var editingPaneID: UUID?
    @State private var isAddingPane: Bool = false

    /// Stateless detector. Held as a `let` so SwiftUI doesn't recreate
    /// it on every body eval. Branch resolution happens lazily inside
    /// the row builder, once per pane per render — reading `.git/HEAD`
    /// is sub-ms so caching is not worth the staleness risk (the user
    /// could checkout a different branch in another terminal between
    /// popover opens, and we want them to always see the truth).
    private let gitBranchDetector = GitBranchDetector()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if currentProject != nil {
                layoutSection
            }
            content
            if let launcherError = store.lastError as? WorkspaceLauncherError {
                launchErrorBanner(launcherError)
            }
            if let project = currentProject, hasUnassignedPanes(project) {
                unassignedPanesBanner(project)
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

    private func hasUnassignedPanes(_ project: Project) -> Bool {
        project.workspacePanes.contains { $0.layoutSlot == -1 }
    }

    private func unassignedCount(_ project: Project) -> Int {
        project.workspacePanes.filter { $0.layoutSlot == -1 }.count
    }

    /// Resolves the absolute folder URL for a pane (project root +
    /// relative cwd) and asks the GitBranchDetector for its current
    /// branch. Returns nil when there is no project root, when the
    /// folder doesn't exist, or when no `.git` is found up the tree.
    private func branch(for pane: WorkspacePane) -> String? {
        guard hasProjectRoot else { return nil }
        let rootURL = URL(fileURLWithPath: projectRoot)
        let absoluteFolder: URL
        if pane.relativeCwd == "." || pane.relativeCwd.isEmpty {
            absoluteFolder = rootURL
        } else {
            absoluteFolder = rootURL.appendingPathComponent(pane.relativeCwd)
        }
        return gitBranchDetector.detectBranch(in: absoluteFolder)
    }

    private func paneLabel(for slot: Int, in project: Project) -> String {
        project.workspacePanes.first { $0.layoutSlot == slot }?.label ?? "—"
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

            if currentProject != nil && !isReadOnly {
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

                Spacer()
                    .frame(width: DevtailTokens.Spacing.gapLarge)
            }

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

    // MARK: - Layout section

    @ViewBuilder
    private var layoutSection: some View {
        if let project = currentProject {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
                Text("LAYOUT")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .tracking(0.5)

                WorkspaceLayoutPicker(
                    layout: Binding(
                        get: { project.layout },
                        set: { _ in }
                    ),
                    onChange: { newLayout in
                        store.setLayout(for: project, layout: newLayout)
                    }
                )

                WorkspaceLayoutThumbnail(
                    layout: project.layout,
                    size: CGSize(width: 200, height: 130),
                    slotLabels: slotLabels(for: project),
                    onSlotMenu: { slot in
                        AnyView(slotMenu(slot: slot, project: project))
                    }
                )
            }
            .padding(.bottom, DevtailTokens.Spacing.gapMedium)
        }
    }

    private func slotLabels(for project: Project) -> [Int: String] {
        var labels: [Int: String] = [:]
        for slot in 0 ..< project.layout.slotCount {
            labels[slot] = paneLabel(for: slot, in: project)
        }
        return labels
    }

    @ViewBuilder
    private func slotMenu(slot: Int, project: Project) -> some View {
        let currentLabel = paneLabel(for: slot, in: project)
        Menu {
            ForEach(sortedPanes, id: \.id) { pane in
                Button(pane.label) {
                    store.assignPaneToSlot(pane: pane, slot: slot)
                }
            }
            // Slot 0 OMITS the "Unassigned" option — it is the anchor slot
            // and cannot be left empty without breaking the launcher.
            if slot != 0 {
                Divider()
                Button("Unassigned") {
                    if let pane = project.workspacePanes.first(where: { $0.layoutSlot == slot }) {
                        store.assignPaneToSlot(pane: pane, slot: -1)
                    }
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(currentLabel)
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
            }
            .padding(.horizontal, DevtailTokens.Spacing.gapSmall)
            .padding(.vertical, DevtailTokens.Spacing.gapTiny)
            .background(DevtailTokens.Colors.inputBackground.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Unassigned panes banner

    @ViewBuilder
    private func unassignedPanesBanner(_ project: Project) -> some View {
        let count = unassignedCount(project)
        HStack(alignment: .top, spacing: DevtailTokens.Spacing.gapSmall) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DevtailTokens.Typography.captionSmall)
                .foregroundStyle(DevtailTokens.Colors.accentOrange)
            Text("\(count) pane\(count == 1 ? "" : "s") not assigned to a slot. Assign them using the layout dropdowns above.")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
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
            Text(isReadOnly
                 ? "Open Manage… to add panes."
                 : "Tap + to add your first pane.")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var paneList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
                ForEach(sortedPanes, id: \.id) { pane in
                    if !isReadOnly && editingPaneID == pane.id {
                        WorkspacePaneEditRow(
                            projectRoot: projectRoot,
                            initialLabel: pane.label,
                            initialRelativeCwd: pane.relativeCwd,
                            initialCommand: pane.command,
                            initialStack: pane.stack,
                            initialEnvironment: pane.environment,
                            onSave: { label, cwd, cmd, stack, env in
                                store.updateWorkspacePane(
                                    pane,
                                    label: label,
                                    relativeCwd: cwd,
                                    command: cmd,
                                    stack: stack,
                                    environment: env
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
                            branch: branch(for: pane),
                            isReadOnly: isReadOnly,
                            canDelete: sortedPanes.count > 1,
                            onEditTap: { startEditingPane(pane.id) },
                            onDelete: { store.deleteWorkspacePane(pane) }
                        )
                    }
                }

                if !isReadOnly && isAddingPane {
                    WorkspacePaneEditRow(
                        projectRoot: projectRoot,
                        onSave: { label, cwd, cmd, stack, env in
                            if let project = currentProject {
                                store.addWorkspacePane(
                                    label: label,
                                    relativeCwd: cwd,
                                    command: cmd,
                                    stack: stack,
                                    environment: env,
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
                case .layoutHasUnassignedSlots(let missing):
                    Text("Cannot launch: slots \(missing.map(String.init).joined(separator: ", ")) have no pane assigned.")
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
        store.createProject(name: "Devtail", color: .green)
        return (store, store.projects[0].id)
    }()
    WorkspacePanel(projectID: projectID)
        .environment(store)
        .frame(width: 320, height: DevtailTokens.Sizes.detailPanelHeight)
        .background(DevtailTokens.Colors.popoverBackground)
}
