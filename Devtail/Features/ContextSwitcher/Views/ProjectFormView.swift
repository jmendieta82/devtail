//
//  ProjectFormView.swift
//  Devtail
//
//  Dual-mode (create + edit) form for a Project. Lives inline inside
//  DashboardRootView's detail pane.
//
//  Public API (do not change without updating DashboardRootView):
//    - projectID: nil for create, UUID for edit
//    - onDismiss: callback invoked on save or cancel
//    - isDirty:   binding the form updates whenever fields differ from
//                 the initial snapshot
//

import SwiftUI
import SwiftData
import AppKit

struct ProjectFormView: View {
    @Environment(ProjectStore.self) private var store

    let projectID: UUID?
    let onDismiss: () -> Void
    @Binding var isDirty: Bool

    @State private var name: String = ""
    @State private var directoryPath: String = ""
    @State private var directoryBookmark: Data?
    @State private var launchTarget: LaunchTarget = .auto
    @State private var runClaudeCode: Bool = true
    @State private var showError: Bool = false
    @State private var didLoad: Bool = false
    @State private var nameWasEditedManually: Bool = false
    @State private var suppressNameChangeTracking: Bool = false
    @State private var initialSnapshot: FormSnapshot?

    @State private var editingPane: WorkspacePane?
    @State private var isAddingPane: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSection) {
                header
                directoryField
                nameField
                if !isEditMode {
                    claudeCodeToggle
                }
                preview
                if isEditMode, let project = editingProject {
                    layoutSection(for: project)
                    processesSection(for: project)
                    quickLinksSection(for: project)
                }
                if showError, let error = store.lastError {
                    Text(error.localizedDescription)
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(.red)
                }
                actions
            }
            .padding(DevtailTokens.Spacing.dashboardPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadIfNeeded() }
        .onChange(of: name) { _, _ in
            if !suppressNameChangeTracking {
                nameWasEditedManually = true
            }
            recomputeDirty()
        }
        .onChange(of: directoryPath) { _, _ in recomputeDirty() }
        .sheet(item: $editingPane) { pane in
            paneEditSheet(for: pane)
        }
        .sheet(isPresented: $isAddingPane) {
            if let project = editingProject {
                paneAddSheet(for: project)
            }
        }
        .onChange(of: editingProject == nil) { _, isGone in
            if isGone {
                editingPane = nil
                isAddingPane = false
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        Text(title)
            .font(DevtailTokens.Typography.titleLarge)
            .foregroundStyle(DevtailTokens.Colors.textPrimary)
    }

    private var directoryField: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.sectionTitleBottom) {
            fieldLabel("Directory")
            HStack(spacing: DevtailTokens.Spacing.gapMedium) {
                Text(directoryPath.isEmpty ? "No folder selected" : directoryPath)
                    .font(DevtailTokens.Typography.monoSmall)
                    .foregroundStyle(directoryPath.isEmpty
                        ? DevtailTokens.Colors.textPlaceholder
                        : DevtailTokens.Colors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DevtailTokens.Spacing.gapLarge)
                    .padding(.vertical, DevtailTokens.Spacing.gapMedium)
                    .background(inputBackground)

                Button("Choose folder…") { chooseDirectory() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.sectionTitleBottom) {
            fieldLabel("Project name")
            TextField(
                "",
                text: $name,
                prompt: Text(directoryPath.isEmpty
                    ? "Choose a directory first"
                    : "My awesome project")
            )
            .textFieldStyle(.plain)
            .font(DevtailTokens.Typography.bodyDefault)
            .foregroundStyle(DevtailTokens.Colors.textPrimary)
            .disabled(directoryPath.isEmpty)
            .padding(.horizontal, DevtailTokens.Spacing.gapLarge)
            .padding(.vertical, DevtailTokens.Spacing.gapMedium)
            .background(inputBackground)
            .opacity(directoryPath.isEmpty ? 0.5 : 1.0)
        }
    }

    private var claudeCodeToggle: some View {
        Toggle(isOn: $runClaudeCode) {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
                Text("Run Claude Code in this project")
                    .font(DevtailTokens.Typography.bodyDefault)
                    .foregroundStyle(DevtailTokens.Colors.textPrimary)
                Text("Pre-fills the default pane command with 'claude' so launching the workspace opens Claude Code automatically.")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
        .tint(DevtailTokens.Colors.accentPrimary)
        .disabled(directoryPath.isEmpty)
        .opacity(directoryPath.isEmpty ? 0.5 : 1.0)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.sectionTitleBottom) {
            fieldLabel("Preview")
            ProjectRowView(
                name: trimmedName.isEmpty ? "Project name" : trimmedName,
                isSelected: false,
                isInteractive: false,
                onTap: nil,
                onEdit: nil,
                onDelete: nil
            )
            .padding(.horizontal, DevtailTokens.Spacing.cardPadding)
            .padding(.vertical, DevtailTokens.Spacing.gapMedium)
            .background(
                RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                    .fill(DevtailTokens.Colors.accentPrimary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                    .stroke(
                        DevtailTokens.Colors.accentPrimary.opacity(0.20),
                        lineWidth: DevtailTokens.BorderWidth.default
                    )
            )
        }
    }

    private var actions: some View {
        HStack {
            Spacer()
            Button("Cancel") { cancel() }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)

            Button(submitLabel) { submit() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
        }
        .padding(.top, DevtailTokens.Spacing.gapLarge)
    }

    // MARK: - Edit-mode sections (live on the store)

    private func sortedPanes(for project: Project) -> [WorkspacePane] {
        project.workspacePanes.sorted { $0.order < $1.order }
    }

    private func layoutSection(for project: Project) -> some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapMedium) {
            SectionHeader(title: "LAYOUT")
            WorkspaceLayoutPicker(
                selected: project.layout,
                onSelect: { store.setLayout(for: project, layout: $0) },
                axis: .horizontal
            )
        }
    }

    private func processesSection(for project: Project) -> some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapMedium) {
            SectionHeader(title: "PROCESSES")
            ForEach(sortedPanes(for: project)) { pane in
                HStack {
                    VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
                        Text(pane.label)
                            .font(DevtailTokens.Typography.bodySmall)
                            .foregroundStyle(DevtailTokens.Colors.textPrimary)
                        Text(pane.command)
                            .font(DevtailTokens.Typography.caption.monospaced())
                            .foregroundStyle(DevtailTokens.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button("Edit") { editingPane = pane }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button(role: .destructive) {
                        store.deleteWorkspacePane(pane)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            Button {
                isAddingPane = true
            } label: {
                Label("Add process", systemImage: "plus")
            }
        }
    }

    private func quickLinksSection(for project: Project) -> some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapMedium) {
            SectionHeader(title: "QUICK LINKS")
            QuickLinksPanel(projectID: project.id, hideTitle: true)
        }
    }

    @ViewBuilder
    private func paneEditSheet(for pane: WorkspacePane) -> some View {
        if let project = editingProject {
            WorkspacePaneEditRow(
                projectRoot: project.directoryPath,
                initialLabel: pane.label,
                initialRelativeCwd: pane.relativeCwd,
                initialCommand: pane.command,
                initialStack: pane.stack,
                initialIsFrontend: pane.isFrontend,
                initialLocalhostUrl: pane.localhostUrl,
                initialEnvironment: pane.environment,
                onSave: { label, cwd, command, stack, isFrontend, localhostUrl, env in
                    store.updateWorkspacePane(
                        pane,
                        label: label,
                        relativeCwd: cwd,
                        command: command,
                        stack: stack,
                        isFrontend: isFrontend,
                        localhostUrl: localhostUrl,
                        environment: env
                    )
                    editingPane = nil
                },
                onCancel: { editingPane = nil }
            )
            .padding(DevtailTokens.Spacing.dashboardPadding)
        }
    }

    @ViewBuilder
    private func paneAddSheet(for project: Project) -> some View {
        WorkspacePaneEditRow(
            projectRoot: project.directoryPath,
            onSave: { label, cwd, command, stack, isFrontend, localhostUrl, env in
                store.addWorkspacePane(
                    label: label,
                    relativeCwd: cwd,
                    command: command,
                    stack: stack,
                    isFrontend: isFrontend,
                    localhostUrl: localhostUrl,
                    environment: env,
                    to: project
                )
                isAddingPane = false
            },
            onCancel: { isAddingPane = false }
        )
        .padding(DevtailTokens.Spacing.dashboardPadding)
    }

    // MARK: - Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(DevtailTokens.Typography.caption)
            .foregroundStyle(DevtailTokens.Colors.textTertiary)
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: DevtailTokens.Radius.searchField)
            .fill(DevtailTokens.Colors.accentPrimary.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: DevtailTokens.Radius.searchField)
                    .stroke(
                        DevtailTokens.Colors.accentPrimary.opacity(0.20),
                        lineWidth: DevtailTokens.BorderWidth.default
                    )
            )
    }

    // MARK: - Computed

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEditMode: Bool {
        projectID != nil
    }

    private var editingProject: Project? {
        guard let projectID else { return nil }
        return store.projects.first(where: { $0.id == projectID })
    }

    private var title: String {
        isEditMode ? "Edit project" : "New project"
    }

    private var submitLabel: String {
        isEditMode ? "Save project" : "Create project"
    }

    private var canSubmit: Bool {
        !trimmedName.isEmpty && !directoryPath.isEmpty
    }

    // MARK: - Lifecycle

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true

        if let projectID,
           let project = store.projects.first(where: { $0.id == projectID }) {
            suppressNameChangeTracking = true
            name = project.name
            directoryPath = project.directoryPath
            directoryBookmark = project.directoryBookmark
            launchTarget = project.launchTarget
            nameWasEditedManually = true
            DispatchQueue.main.async {
                suppressNameChangeTracking = false
            }
        }

        initialSnapshot = currentSnapshot()
        isDirty = false
    }

    // MARK: - Dirty state

    private func currentSnapshot() -> FormSnapshot {
        FormSnapshot(name: name, directoryPath: directoryPath, launchTarget: launchTarget)
    }

    private func recomputeDirty() {
        guard let initialSnapshot else { return }
        let newValue = currentSnapshot() != initialSnapshot
        if newValue != isDirty {
            isDirty = newValue
        }
    }

    // MARK: - Actions

    private func submit() {
        guard canSubmit else { return }

        if let projectID,
           let project = store.projects.first(where: { $0.id == projectID }) {
            project.launchTarget = launchTarget
            store.updateProject(
                project,
                name: trimmedName,
                notes: project.notes,
                directoryPath: directoryPath,
                directoryBookmark: directoryBookmark
            )
        } else {
            store.createProject(
                name: trimmedName,
                directoryPath: directoryPath,
                directoryBookmark: directoryBookmark,
                runClaudeCode: runClaudeCode,
                launchTarget: launchTarget
            )
        }

        if store.lastError == nil {
            resetState()
            onDismiss()
        } else {
            showError = true
        }
    }

    private func cancel() {
        resetState()
        onDismiss()
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            directoryPath = url.path
            // Capture a security-scoped bookmark so the path survives
            // restarts and can be passed to external apps under sandbox.
            directoryBookmark = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            if !nameWasEditedManually && trimmedName.isEmpty {
                suppressNameChangeTracking = true
                name = url.lastPathComponent
                DispatchQueue.main.async {
                    suppressNameChangeTracking = false
                }
            }
        }
    }

    private func resetState() {
        name = ""
        directoryPath = ""
        launchTarget = .auto
        runClaudeCode = true
        showError = false
        didLoad = false
        initialSnapshot = nil
        isDirty = false
        nameWasEditedManually = false
        suppressNameChangeTracking = false
    }
}

private struct FormSnapshot: Equatable {
    let name: String
    let directoryPath: String
    let launchTarget: LaunchTarget
}
