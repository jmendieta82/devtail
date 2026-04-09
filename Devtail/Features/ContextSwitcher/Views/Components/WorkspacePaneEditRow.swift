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
//  Command (optional), Split direction. Save is disabled until label and
//  relativeCwd are both populated and the split direction is valid.
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
    let initialSplitDirection: String
    let initialStack: String?

    /// Stack auto-detection registry. Defaults to the production list,
    /// but is injectable so tests and previews can swap in deterministic
    /// fakes without touching the filesystem.
    let detectorRegistry: StackDetectorRegistry

    let onSave: (
        _ label: String,
        _ relativeCwd: String,
        _ command: String,
        _ splitDirection: String,
        _ stack: String?
    ) -> Void
    let onCancel: () -> Void

    @State private var label: String
    @State private var stack: String
    @State private var relativeCwd: String
    @State private var command: String
    @State private var splitDirection: String
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
        initialSplitDirection: String = "none",
        initialStack: String? = nil,
        detectorRegistry: StackDetectorRegistry = .default,
        onSave: @escaping (String, String, String, String, String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.projectRoot = projectRoot
        self.initialLabel = initialLabel
        self.initialRelativeCwd = initialRelativeCwd
        self.initialCommand = initialCommand
        self.initialSplitDirection = initialSplitDirection
        self.initialStack = initialStack
        self.detectorRegistry = detectorRegistry
        self.onSave = onSave
        self.onCancel = onCancel
        _label = State(initialValue: initialLabel)
        _stack = State(initialValue: initialStack ?? "")
        _relativeCwd = State(initialValue: initialRelativeCwd)
        _command = State(initialValue: initialCommand)
        _splitDirection = State(initialValue: initialSplitDirection)
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

            // Split direction picker
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
                Text("SPLIT")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .tracking(0.5)
                Picker("Split direction", selection: $splitDirection) {
                    Text("No split").tag("none")
                    Text("Split right").tag("right")
                    Text("Split down").tag("down")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
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
        .padding(DevtailTokens.Spacing.gapMedium)
        .background(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.projectRow)
                .fill(DevtailTokens.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.projectRow)
                .stroke(DevtailTokens.Colors.borderSubtle,
                        lineWidth: DevtailTokens.BorderWidth.default)
        )
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

        // The chosen path must start with the root path AND be inside it
        // (not the root itself — a pane pointing at the root is allowed,
        // the user might have a single-folder project).
        guard chosenComponents.count >= rootComponents.count,
              Array(chosenComponents.prefix(rootComponents.count)) == rootComponents
        else {
            chooserError = "Folder must be inside the project root (\(rootURL.lastPathComponent))."
            return
        }

        // Compute the relative components. Empty → the root itself → ".".
        let relativeComponents = Array(chosenComponents.dropFirst(rootComponents.count))
        let computed = relativeComponents.isEmpty
            ? "."
            : relativeComponents.joined(separator: "/")

        chooserError = nil
        relativeCwd = computed

        // Auto-fill label only when the user has not typed one. We respect
        // an explicit label the user entered before picking the folder.
        if label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            label = chosen.lastPathComponent
        }

        // Kick off stack auto-detection. The detector IO suspends the
        // main actor (it doesn't block it), so the editor stays responsive
        // while we sniff the folder. Result is filled in inside the Task.
        runStackDetection(at: chosenStandardized)
    }

    /// Runs the configured detector registry against the chosen folder
    /// and, on success, fills in `stack` and `command` — but only when
    /// those fields are still empty. Anything the user already typed is
    /// preserved verbatim, matching how the label auto-fill works above.
    ///
    /// Concurrency note: this uses `Task { }` (NOT `Task.detached`) so
    /// the closure inherits the @MainActor isolation of the View. The
    /// `await registry.detectBestMatch(...)` suspends the main actor
    /// during the actual filesystem IO — the detectors are `Sendable`
    /// and run on the cooperative pool — so the UI stays responsive.
    /// `Task.detached` is the wrong tool here: it would copy the View
    /// struct and mutations would not reach the real `@State` storage.
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
            // Root itself — show the project folder name rather than a
            // cryptic ".".
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
            && isValidSplitDirection(splitDirection)
            && chooserError == nil
    }

    private func commitIfValid() {
        guard canSave else { return }
        let stackValue: String? = trimmedStack.isEmpty ? nil : trimmedStack
        onSave(trimmedLabel, relativeCwd, command, splitDirection, stackValue)
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
