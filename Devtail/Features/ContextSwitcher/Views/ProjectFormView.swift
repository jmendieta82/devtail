//
//  ProjectFormView.swift
//  Devtail
//
//  Dual-mode (create + edit) form for a Project. Hosted in a WindowGroup
//  scene that receives a `UUID?` value via the WindowGroup binding:
//    nil   → create mode
//    UUID  → edit mode (pre-fills from store on appear)
//
//  Notes is preserved on the model but intentionally hidden from this form
//  per locked decision (not in mockup, MVP-first).
//

import SwiftUI
import SwiftData

struct ProjectFormView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var name: String = ""
    @State private var stack: String = ""
    @State private var environment: ProjectEnvironment = .dev
    @State private var color: ProjectColor = .gray
    @State private var directoryPath: String = ""
    @State private var showError: Bool = false
    @State private var didLoad: Bool = false

    let projectID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSection) {
            // ─── Form fields ───
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapLarge) {
                // Project name
                VStack(alignment: .leading, spacing: DevtailTokens.Spacing.sectionTitleBottom) {
                    Text("Project name")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    TextField("", text: $name, prompt: Text("My awesome project"))
                        .textFieldStyle(.plain)
                        .font(DevtailTokens.Typography.bodyDefault)
                        .foregroundStyle(DevtailTokens.Colors.textPrimary)
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
                }

                // Stack
                VStack(alignment: .leading, spacing: DevtailTokens.Spacing.sectionTitleBottom) {
                    Text("Stack / tech")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    TextField("", text: $stack, prompt: Text("Swift + SwiftUI"))
                        .textFieldStyle(.plain)
                        .font(DevtailTokens.Typography.bodyDefault)
                        .foregroundStyle(DevtailTokens.Colors.textPrimary)
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
                }

                // Environment
                VStack(alignment: .leading, spacing: DevtailTokens.Spacing.sectionTitleBottom) {
                    Text("Environment")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    EnvironmentPicker(selection: $environment)
                }

                // Color
                VStack(alignment: .leading, spacing: DevtailTokens.Spacing.sectionTitleBottom) {
                    Text("Color")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    ColorPickerRow(selection: $color)
                }

                // Directory
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
            }

            // ─── Live preview ───
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.sectionTitleBottom) {
                Text("Preview")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                ProjectRowView(
                    name: trimmedName.isEmpty ? "Project name" : trimmedName,
                    color: color,
                    environment: environment,
                    stack: trimmedStack.isEmpty ? nil : trimmedStack,
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
        .frame(width: 460, height: 580)
        .background(DevtailTokens.Colors.popoverBackground)
        .navigationTitle(title)
        .onAppear { loadIfNeeded() }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedStack: String {
        stack.trimmingCharacters(in: .whitespacesAndNewlines)
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
        !trimmedName.isEmpty
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard
            let projectID,
            let project = store.projects.first(where: { $0.id == projectID })
        else {
            // Create mode OR edit target was deleted between open and appear.
            // For the second case we silently fall back to create mode — the
            // user sees an empty form. We do NOT auto-dismiss because that's
            // surprising.
            return
        }
        name = project.name
        stack = project.stack ?? ""
        environment = project.environment
        color = project.color
        directoryPath = project.directoryPath
    }

    private func submit() {
        guard canSubmit else { return }

        let resolvedStack: String? = trimmedStack.isEmpty ? nil : trimmedStack

        if let projectID,
           let project = store.projects.first(where: { $0.id == projectID }) {
            // Edit mode — preserve notes (form doesn't show them).
            store.updateProject(
                project,
                name: trimmedName,
                notes: project.notes,
                color: color,
                environment: environment,
                stack: resolvedStack,
                directoryPath: directoryPath
            )
        } else {
            // Create mode
            store.createProject(
                name: trimmedName,
                color: color,
                environment: environment,
                stack: resolvedStack,
                directoryPath: directoryPath
            )
        }

        if store.lastError == nil {
            resetState()
            dismissWindow(id: WindowID.projectForm, value: projectID)
        } else {
            showError = true
        }
    }

    private func cancel() {
        resetState()
        dismissWindow(id: WindowID.projectForm, value: projectID)
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            directoryPath = url.path
        }
    }

    private func resetState() {
        name = ""
        stack = ""
        environment = .dev
        color = .gray
        directoryPath = ""
        showError = false
        didLoad = false
    }
}

#Preview("Create mode") {
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
    ProjectFormView(projectID: nil)
        .environment(store)
}

#Preview("Edit mode") {
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
            color: .green,
            environment: .prod,
            stack: "Swift + SwiftUI"
        )
        return (store, store.projects[0].id)
    }()
    ProjectFormView(projectID: projectID)
        .environment(store)
}
