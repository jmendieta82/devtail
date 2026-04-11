//
//  ProjectFormView.swift
//  Devtail
//
//  Dual-mode (create + edit) form for a Project. Lives inline inside
//  DashboardRootView's detail pane (not a sheet, not a separate window).
//  The caller passes:
//    - projectID: nil for create, UUID for edit
//    - onDismiss: callback invoked on save or cancel
//    - isDirty:   binding the form updates whenever its fields differ from
//                 the initial snapshot. The dashboard reads this to decide
//                 whether to show a "discard changes" alert on sidebar taps.
//
//  Notes is preserved on the model but intentionally hidden from this form
//  per locked decision (not in mockup, MVP-first).
//

import SwiftUI
import SwiftData

struct ProjectFormView: View {
    @Environment(ProjectStore.self) private var store

    @State private var name: String = ""
    @State private var color: ProjectColor = .gray
    @State private var directoryPath: String = ""
    @State private var runClaudeCode: Bool = true
    @State private var showError: Bool = false
    @State private var didLoad: Bool = false

    /// Tracks whether the user has manually typed in the Name field. When
    /// false, picking a directory will auto-fill the name from the folder's
    /// last path component. Once the user edits the name manually, we stop
    /// auto-filling to avoid clobbering their choice.
    @State private var nameWasEditedManually: Bool = false

    /// Set to `true` momentarily while `chooseDirectory` writes an auto-filled
    /// name, so the `onChange(of: name)` handler does not mistake the write
    /// for a manual edit.
    @State private var suppressNameChangeTracking: Bool = false

    /// Snapshot of the values the form started with. Used to compute dirty
    /// state. `nil` until loadIfNeeded runs, so the form is considered clean
    /// until it has a baseline to compare against.
    @State private var initialSnapshot: FormSnapshot?

    let projectID: UUID?
    let onDismiss: () -> Void
    @Binding var isDirty: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSection) {
            formHeader

            // ─── Form fields ───
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapLarge) {
                // Directory (required, first)
                VStack(alignment: .leading, spacing: DevtailTokens.Spacing.sectionTitleBottom) {
                    Text("Directory")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
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
                            .background(
                                RoundedRectangle(cornerRadius: DevtailTokens.Radius.searchField)
                                    .fill(DevtailTokens.Colors.inputBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DevtailTokens.Radius.searchField)
                                    .stroke(DevtailTokens.Colors.borderSubtle,
                                            lineWidth: DevtailTokens.BorderWidth.default)
                            )
                        Button("Choose folder…") {
                            chooseDirectory()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                // Project name (auto-filled from directory, editable)
                VStack(alignment: .leading, spacing: DevtailTokens.Spacing.sectionTitleBottom) {
                    Text("Project name")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
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
                    .background(
                        RoundedRectangle(cornerRadius: DevtailTokens.Radius.searchField)
                            .fill(DevtailTokens.Colors.inputBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DevtailTokens.Radius.searchField)
                            .stroke(
                                DevtailTokens.Colors.borderSubtle,
                                lineWidth: DevtailTokens.BorderWidth.default
                            )
                    )
                    .opacity(directoryPath.isEmpty ? 0.5 : 1.0)
                }

                // Color
                VStack(alignment: .leading, spacing: DevtailTokens.Spacing.sectionTitleBottom) {
                    Text("Color")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    ColorPickerRow(selection: $color)
                        .disabled(directoryPath.isEmpty)
                        .opacity(directoryPath.isEmpty ? 0.5 : 1.0)
                }

                // Claude Code toggle — only shown in create mode
                if !isEditMode {
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
                    .tint(DevtailTokens.Colors.accentGreen)
                    .disabled(directoryPath.isEmpty)
                    .opacity(directoryPath.isEmpty ? 0.5 : 1.0)
                }
            }

            // ─── Live preview ───
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.sectionTitleBottom) {
                Text("Preview")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                ProjectRowView(
                    name: trimmedName.isEmpty ? "Project name" : trimmedName,
                    color: color,
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
                        .fill(DevtailTokens.Colors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                        .stroke(
                            DevtailTokens.Colors.borderCard,
                            lineWidth: DevtailTokens.BorderWidth.default
                        )
                )
            }

            // ─── Inline error ───
            if showError, let error = store.lastError {
                Text(error.localizedDescription)
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(.red)
            }

            Spacer(minLength: 0)

            // ─── Actions ───
            HStack {
                Spacer()
                Button("Cancel") {
                    cancel()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)

                Button(submitLabel) {
                    submit()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
            }
        }
        .padding(DevtailTokens.Spacing.dashboardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { loadIfNeeded() }
        .onChange(of: name) { _, _ in
            if !suppressNameChangeTracking {
                nameWasEditedManually = true
            }
            recomputeDirty()
        }
        .onChange(of: color) { _, _ in recomputeDirty() }
        .onChange(of: directoryPath) { _, _ in recomputeDirty() }
    }

    // MARK: - Header (title inside the dashboard detail area)

    private var formHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(DevtailTokens.Typography.titleLarge)
                .foregroundStyle(DevtailTokens.Colors.textPrimary)
            Spacer()
        }
    }

    // MARK: - Computed

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEditMode: Bool {
        projectID != nil
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

        // Load existing values (edit mode) or leave defaults (create mode).
        if let projectID,
           let project = store.projects.first(where: { $0.id == projectID }) {
            suppressNameChangeTracking = true
            name = project.name
            color = project.color
            directoryPath = project.directoryPath
            // In edit mode the user already has a name — treat it as manual
            // so re-picking a directory doesn't clobber it.
            nameWasEditedManually = true
            DispatchQueue.main.async {
                suppressNameChangeTracking = false
            }
        }

        // Snapshot AFTER loading so the baseline reflects the starting point.
        initialSnapshot = currentSnapshot()
        // Whenever we reload, clear dirty — caller should see a fresh form.
        isDirty = false
    }

    // MARK: - Dirty state

    private func currentSnapshot() -> FormSnapshot {
        FormSnapshot(
            name: name,
            color: color,
            directoryPath: directoryPath
        )
    }

    private func recomputeDirty() {
        guard let initialSnapshot else {
            // loadIfNeeded has not run yet; ignore transient onChange firings.
            return
        }
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
            // Edit mode — preserve notes (form doesn't show them).
            store.updateProject(
                project,
                name: trimmedName,
                notes: project.notes,
                color: color,
                directoryPath: directoryPath
            )
        } else {
            // Create mode
            store.createProject(
                name: trimmedName,
                color: color,
                directoryPath: directoryPath,
                runClaudeCode: runClaudeCode
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
            // Auto-fill the project name from the folder's last component,
            // but only if the user hasn't manually typed anything yet.
            if !nameWasEditedManually && trimmedName.isEmpty {
                suppressNameChangeTracking = true
                name = url.lastPathComponent
                // Reset the guard on the next runloop tick so subsequent
                // keystrokes are tracked as manual edits again.
                DispatchQueue.main.async {
                    suppressNameChangeTracking = false
                }
            }
        }
    }

    private func resetState() {
        name = ""
        color = .gray
        directoryPath = ""
        runClaudeCode = true
        showError = false
        didLoad = false
        initialSnapshot = nil
        isDirty = false
        nameWasEditedManually = false
        suppressNameChangeTracking = false
    }
}

/// Snapshot of the form fields, used as the baseline for dirty detection.
/// Equatable so dirty is a single `!=` away.
private struct FormSnapshot: Equatable {
    let name: String
    let color: ProjectColor
    let directoryPath: String
}

#Preview("Create mode") {
    @Previewable @State var dirty = false
    let store: ProjectStore = {
        let container = PersistenceController.makeContainer(inMemory: true)
        let repository = ProjectRepository(context: container.mainContext)
        let linkRepository = QuickLinkRepository(context: container.mainContext)
        let paneRepository = WorkspacePaneRepository(context: container.mainContext)
        return ProjectStore(
            repository: repository,
            quickLinkRepository: linkRepository,
            workspacePaneRepository: paneRepository,
            launcher: WorkspaceLauncher()
        )
    }()
    ProjectFormView(projectID: nil, onDismiss: {}, isDirty: $dirty)
        .environment(store)
        .frame(width: 700, height: 600)
        .background(DevtailTokens.Colors.appBackground)
        .preferredColorScheme(.dark)
}

#Preview("Edit mode") {
    @Previewable @State var dirty = false
    let (store, projectID): (ProjectStore, UUID) = {
        let container = PersistenceController.makeContainer(inMemory: true)
        let repository = ProjectRepository(context: container.mainContext)
        let linkRepository = QuickLinkRepository(context: container.mainContext)
        let paneRepository = WorkspacePaneRepository(context: container.mainContext)
        let store = ProjectStore(
            repository: repository,
            quickLinkRepository: linkRepository,
            workspacePaneRepository: paneRepository,
            launcher: WorkspaceLauncher()
        )
        store.createProject(
            name: "Devtail",
            color: .green
        )
        return (store, store.projects[0].id)
    }()
    ProjectFormView(projectID: projectID, onDismiss: {}, isDirty: $dirty)
        .environment(store)
        .frame(width: 700, height: 600)
        .background(DevtailTokens.Colors.appBackground)
        .preferredColorScheme(.dark)
}
