//
//  WorkspacePaneEditRow.swift
//  Devtail
//
//  Inline editor for a WorkspacePane (create or edit mode). Directory is
//  picked via NSOpenPanel, never typed. The panel opens rooted at the
//  project's directoryPath and validates that the selected folder is
//  inside the project root — otherwise an inline error is shown.
//
//  Fields, in order: Label, Stack/tech, Directory (read-only + picker),
//  Command (optional), Environment. Slot assignment is handled by the
//  layout picker in WorkspacePanel — not here.
//

import SwiftUI
import AppKit

struct WorkspacePaneEditRow: View {
    /// Absolute filesystem path of the project root. All chosen folders
    /// must live inside this path; the editor will reject anything else.
    let projectRoot: String

    let initialLabel: String
    let initialRelativeCwd: String
    let initialCommand: String
    let initialStack: String?
    let initialEnvironment: ProjectEnvironment?

    /// Stack auto-detection registry. Defaults to the production list,
    /// but is injectable so tests and previews can swap in deterministic
    /// fakes without touching the filesystem.
    let detectorRegistry: StackDetectorRegistry

    let onSave: (
        _ label: String,
        _ relativeCwd: String,
        _ command: String,
        _ stack: String?,
        _ environment: ProjectEnvironment?
    ) -> Void
    let onCancel: () -> Void

    @State private var label: String
    @State private var stack: String
    @State private var relativeCwd: String
    @State private var command: String
    @State private var environment: ProjectEnvironment?
    @State private var chooserError: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case label, stack, command
    }

    init(
        projectRoot: String,
        initialLabel: String = "",
        initialRelativeCwd: String = "",
        initialCommand: String = "",
        initialStack: String? = nil,
        initialEnvironment: ProjectEnvironment? = nil,
        detectorRegistry: StackDetectorRegistry = .default,
        onSave: @escaping (String, String, String, String?, ProjectEnvironment?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.projectRoot = projectRoot
        self.initialLabel = initialLabel
        self.initialRelativeCwd = initialRelativeCwd
        self.initialCommand = initialCommand
        self.initialStack = initialStack
        self.initialEnvironment = initialEnvironment
        self.detectorRegistry = detectorRegistry
        self.onSave = onSave
        self.onCancel = onCancel
        _label = State(initialValue: initialLabel)
        _stack = State(initialValue: initialStack ?? "")
        _relativeCwd = State(initialValue: initialRelativeCwd)
        _command = State(initialValue: initialCommand)
        _environment = State(initialValue: initialEnvironment)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapMedium) {
            // Label
            labeledField(title: "LABEL") {
                styledTextField(
                    text: $label,
                    prompt: "frontend",
                    isInvalid: labelIsInvalid,
                    focus: .label,
                    onSubmit: { focusedField = .stack }
                )
            }

            // Stack / tech
            labeledField(title: "STACK / TECH") {
                styledTextField(
                    text: $stack,
                    prompt: "TypeScript, Django, …",
                    isInvalid: false,
                    focus: .stack,
                    onSubmit: { focusedField = .command }
                )
            }

            // Directory — read-only display + picker button
            labeledField(title: "DIRECTORY") {
                VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
                    HStack(spacing: DevtailTokens.Spacing.gapMedium) {
                        Text(relativeCwdDisplay)
                            .font(DevtailTokens.Typography.monoSmall)
                            .foregroundStyle(relativeCwd.isEmpty
                                ? DevtailTokens.Colors.textPlaceholder
                                : DevtailTokens.Colors.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
                            .padding(.vertical, DevtailTokens.Spacing.gapSmall)
                            .background(
                                RoundedRectangle(cornerRadius: DevtailTokens.Radius.searchField)
                                    .fill(DevtailTokens.Colors.inputBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DevtailTokens.Radius.searchField)
                                    .stroke(
                                        chooserError != nil
                                            ? Color.red.opacity(0.8)
                                            : DevtailTokens.Colors.borderSubtle,
                                        lineWidth: chooserError != nil
                                            ? 1
                                            : DevtailTokens.BorderWidth.default
                                    )
                            )
                        Button("Choose folder…") {
                            chooseDirectory()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if let chooserError {
                        Text(chooserError)
                            .font(DevtailTokens.Typography.captionSmall)
                            .foregroundStyle(.red)
                    }
                }
            }

            // Command (optional)
            labeledField(title: "COMMAND (OPTIONAL)") {
                styledTextField(
                    text: $command,
                    prompt: "npm run dev",
                    isInvalid: false,
                    focus: .command,
                    onSubmit: { commitIfValid() }
                )
            }

            // Environment picker (optional — defaults to None)
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
                Text("ENVIRONMENT")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .tracking(0.5)
                EnvironmentPicker(selection: $environment)
            }

            // Actions
            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Spacer()
                Button("Save") {
                    commitIfValid()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!canSave)
            }
        }
        .padding(DevtailTokens.Spacing.gapLarge)
        .glassEffect(in: RoundedRectangle(cornerRadius: DevtailTokens.Radius.card))
    }

    // MARK: - Reusable field chrome

    @ViewBuilder
    private func labeledField<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
            Text(title)
                .font(DevtailTokens.Typography.captionSmall)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
                .tracking(0.5)
            content()
        }
    }

    @ViewBuilder
    private func styledTextField(
        text: Binding<String>,
        prompt: String,
        isInvalid: Bool,
        focus: Field,
        onSubmit: @escaping () -> Void
    ) -> some View {
        TextField("", text: text, prompt: Text(prompt))
            .textFieldStyle(.plain)
            .font(DevtailTokens.Typography.bodySmall)
            .foregroundStyle(DevtailTokens.Colors.textPrimary)
            .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
            .padding(.vertical, DevtailTokens.Spacing.gapSmall)
            .background(
                RoundedRectangle(cornerRadius: DevtailTokens.Radius.searchField)
                    .fill(DevtailTokens.Colors.inputBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DevtailTokens.Radius.searchField)
                    .stroke(
                        isInvalid ? Color.red.opacity(0.8) : DevtailTokens.Colors.borderSubtle,
                        lineWidth: isInvalid ? 1 : DevtailTokens.BorderWidth.default
                    )
            )
            .focused($focusedField, equals: focus)
            .onSubmit(onSubmit)
    }

    // MARK: - NSOpenPanel

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if !projectRoot.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: projectRoot)
        }
        guard panel.runModal() == .OK, let chosen = panel.url else {
            return
        }
        applyChosenDirectory(chosen)
    }

    /// Validates the chosen URL against the project root and, on success,
    /// updates `relativeCwd` and (if empty) auto-fills `label` with the
    /// folder name. On failure, stores an error message shown inline.
    private func applyChosenDirectory(_ chosen: URL) {
        guard !projectRoot.isEmpty else {
            chooserError = "Set a project directory first."
            return
        }

        let rootURL = URL(fileURLWithPath: projectRoot).standardizedFileURL
        let chosenStandardized = chosen.standardizedFileURL

        let rootComponents = rootURL.pathComponents
        let chosenComponents = chosenStandardized.pathComponents

        guard chosenComponents.count >= rootComponents.count,
              Array(chosenComponents.prefix(rootComponents.count)) == rootComponents
        else {
            chooserError = "Folder must be inside the project root (\(rootURL.lastPathComponent))."
            return
        }

        let relativeComponents = Array(chosenComponents.dropFirst(rootComponents.count))
        let computed = relativeComponents.isEmpty
            ? "."
            : relativeComponents.joined(separator: "/")

        chooserError = nil
        relativeCwd = computed

        if label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            label = chosen.lastPathComponent
        }

        runStackDetection(at: chosenStandardized)
    }

    /// Runs the configured detector registry against the chosen folder
    /// and, on success, fills in `stack` and `command` — but only when
    /// those fields are still empty. Anything the user already typed is
    /// preserved verbatim, matching how the label auto-fill works above.
    private func runStackDetection(at folder: URL) {
        let registry = detectorRegistry
        Task {
            guard let detected = await registry.detectBestMatch(in: folder) else {
                return
            }
            if stack.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                stack = detected.label
            }
            if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let suggested = detected.suggestedCommand {
                command = suggested
            }
        }
    }

    // MARK: - Display helpers

    private var relativeCwdDisplay: String {
        if relativeCwd.isEmpty {
            return "No folder selected"
        }
        if relativeCwd == "." {
            let last = URL(fileURLWithPath: projectRoot).lastPathComponent
            return last.isEmpty ? "." : "\(last)/"
        }
        return relativeCwd
    }

    // MARK: - Validation

    private var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedStack: String {
        stack.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var labelIsInvalid: Bool {
        label.count > 0 && trimmedLabel.isEmpty
    }

    private var canSave: Bool {
        !trimmedLabel.isEmpty
            && !relativeCwd.isEmpty
            && chooserError == nil
    }

    private func commitIfValid() {
        guard canSave else { return }
        let stackValue: String? = trimmedStack.isEmpty ? nil : trimmedStack
        onSave(trimmedLabel, relativeCwd, command, stackValue, environment)
    }
}

#Preview {
    WorkspacePaneEditRow(
        projectRoot: "/Users/dev/MRN_V2",
        onSave: { _, _, _, _, _ in },
        onCancel: {}
    )
    .padding()
    .frame(width: 560)
    .background(DevtailTokens.Colors.appBackground)
    .preferredColorScheme(.dark)
}
