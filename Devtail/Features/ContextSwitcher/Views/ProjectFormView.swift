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
//                 the initial snapshot (create mode only — edit mode
//                 autosaves valid changes, so it never reports dirty)
//
//  Edit mode autosaves name/directory/launchTarget: on name-field focus
//  loss, on folder pick, and as a safety net on view unmount. Invalid or
//  unchanged values never trigger a write. Create mode is untouched —
//  explicit "Create project" submit with its existing dirty guard.
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
    @State private var showError: Bool = false
    @State private var didLoad: Bool = false
    @State private var nameWasEditedManually: Bool = false
    @State private var suppressNameChangeTracking: Bool = false
    @State private var initialSnapshot: FormSnapshot?

    @State private var editingPane: WorkspacePane?
    @State private var isAddingPane: Bool = false

    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSection) {
                header
                directoryField
                nameField
                preview
                if isEditMode, let project = editingProject {
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
        .onChange(of: isNameFieldFocused) { wasFocused, isFocused in
            if wasFocused && !isFocused {
                autosaveIfNeeded()
            }
        }
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
        .onDisappear { autosaveIfNeeded() }
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
            .focused($isNameFieldFocused)
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
            Button(cancelLabel) { cancel() }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)

            // Edit mode autosaves — no explicit submit button, just Close.
            if !isEditMode {
                Button(submitLabel) { submit() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit)
            }
        }
        .padding(.top, DevtailTokens.Spacing.gapLarge)
    }

    // MARK: - Edit-mode sections (live on the store)

    private func sortedPanes(for project: Project) -> [WorkspacePane] {
        project.workspacePanes.sorted { $0.order < $1.order }
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
                    if project.workspacePanes.count > 1 {
                        Button(role: .destructive) {
                            store.deleteWorkspacePane(pane)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            if project.workspacePanes.isEmpty {
                Text("Add a process to launch this workspace.")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
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
            .frame(minWidth: 560)
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
        .frame(minWidth: 560)
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

    private var cancelLabel: String {
        isEditMode ? "Close" : "Cancel"
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
        // Edit mode autosaves valid changes, so nothing is ever "pending" —
        // the dirty guard (and its discard-confirmation UI) is a create-mode
        // only concept.
        guard !isEditMode, let initialSnapshot else { return }
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

    /// Edit-mode autosave: commits name/directory/launchTarget when the
    /// current values are valid and differ from what's persisted. Called on
    /// name-field focus loss, after picking a folder, and on view unmount.
    /// Mirrors `submit()`'s edit-mode store call exactly (same method, same
    /// arguments) — an invalid or unchanged value is simply left alone, and
    /// an invalid pending edit is discarded rather than committed.
    private func autosaveIfNeeded() {
        guard isEditMode,
              let projectID,
              let project = store.projects.first(where: { $0.id == projectID }) else { return }

        let shouldCommit = ProjectFormAutosave.shouldCommit(
            trimmedName: trimmedName,
            directoryPath: directoryPath,
            launchTarget: launchTarget,
            persistedName: project.name,
            persistedDirectoryPath: project.directoryPath,
            persistedLaunchTarget: project.launchTarget
        )
        guard shouldCommit else { return }

        project.launchTarget = launchTarget
        store.updateProject(
            project,
            name: trimmedName,
            notes: project.notes,
            directoryPath: directoryPath,
            directoryBookmark: directoryBookmark
        )
        showError = store.lastError != nil
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
            autosaveIfNeeded()
        }
    }

    private func resetState() {
        name = ""
        directoryPath = ""
        launchTarget = .auto
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

// MARK: - ProjectFormAutosave

/// Pure commit decision for edit-mode autosave, extracted so it can be
/// unit-tested without spinning up the view. A commit happens only when the
/// pending values are valid (mirrors `canSubmit`: trimmed name and directory
/// both non-empty) AND at least one of them differs from what's already
/// persisted — redundant writes are skipped.
enum ProjectFormAutosave {
    static func shouldCommit(
        trimmedName: String,
        directoryPath: String,
        launchTarget: LaunchTarget,
        persistedName: String,
        persistedDirectoryPath: String,
        persistedLaunchTarget: LaunchTarget
    ) -> Bool {
        guard !trimmedName.isEmpty, !directoryPath.isEmpty else { return false }
        return trimmedName != persistedName
            || directoryPath != persistedDirectoryPath
            || launchTarget != persistedLaunchTarget
    }
}
