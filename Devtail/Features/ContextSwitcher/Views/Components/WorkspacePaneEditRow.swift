//
//  WorkspacePaneEditRow.swift
//  Devtail
//
//  Inline edit row for creating or updating a WorkspacePane.
//  Four inputs: label, relativeCwd, command (optional), splitDirection picker.
//  Save is disabled when label or cwd is empty or splitDirection is invalid.
//

import SwiftUI

struct WorkspacePaneEditRow: View {
    let initialLabel: String
    let initialRelativeCwd: String
    let initialCommand: String
    let initialSplitDirection: String
    let onSave: (_ label: String, _ relativeCwd: String, _ command: String, _ splitDirection: String) -> Void
    let onCancel: () -> Void

    @State private var label: String
    @State private var relativeCwd: String
    @State private var command: String
    @State private var splitDirection: String
    @FocusState private var focusedField: Field?

    private enum Field {
        case label, relativeCwd, command
    }

    init(
        initialLabel: String = "",
        initialRelativeCwd: String = ".",
        initialCommand: String = "",
        initialSplitDirection: String = "none",
        onSave: @escaping (String, String, String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialLabel = initialLabel
        self.initialRelativeCwd = initialRelativeCwd
        self.initialCommand = initialCommand
        self.initialSplitDirection = initialSplitDirection
        self.onSave = onSave
        self.onCancel = onCancel
        _label = State(initialValue: initialLabel)
        _relativeCwd = State(initialValue: initialRelativeCwd)
        _command = State(initialValue: initialCommand)
        _splitDirection = State(initialValue: initialSplitDirection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
            // Label
            TextField("Label", text: $label, prompt: Text("Main"))
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
                            labelIsInvalid ? Color.red.opacity(0.8) : DevtailTokens.Colors.borderSubtle,
                            lineWidth: labelIsInvalid ? 1 : DevtailTokens.BorderWidth.default
                        )
                )
                .focused($focusedField, equals: .label)
                .onSubmit { focusedField = .relativeCwd }

            // Relative cwd
            TextField("Path (relative to root)", text: $relativeCwd, prompt: Text("."))
                .textFieldStyle(.plain)
                .font(DevtailTokens.Typography.monoSmall)
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
                            cwdIsInvalid ? Color.red.opacity(0.8) : DevtailTokens.Colors.borderSubtle,
                            lineWidth: cwdIsInvalid ? 1 : DevtailTokens.BorderWidth.default
                        )
                )
                .focused($focusedField, equals: .relativeCwd)
                .onSubmit { focusedField = .command }

            // Command (optional)
            TextField("Command (optional)", text: $command, prompt: Text("npm run dev"))
                .textFieldStyle(.plain)
                .font(DevtailTokens.Typography.monoSmall)
                .foregroundStyle(DevtailTokens.Colors.textPrimary)
                .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
                .padding(.vertical, DevtailTokens.Spacing.gapSmall)
                .background(
                    RoundedRectangle(cornerRadius: DevtailTokens.Radius.searchField)
                        .fill(DevtailTokens.Colors.inputBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DevtailTokens.Radius.searchField)
                        .stroke(DevtailTokens.Colors.borderSubtle,
                                lineWidth: DevtailTokens.BorderWidth.default)
                )
                .focused($focusedField, equals: .command)
                .onSubmit { commitIfValid() }

            // Split direction picker
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
                Text("Split")
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

    // MARK: - Validation

    private var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedCwd: String {
        relativeCwd.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var labelIsInvalid: Bool {
        label.count > 0 && trimmedLabel.isEmpty
    }

    private var cwdIsInvalid: Bool {
        relativeCwd.count > 0 && trimmedCwd.isEmpty
    }

    private var canSave: Bool {
        !trimmedLabel.isEmpty && !trimmedCwd.isEmpty && isValidSplitDirection(splitDirection)
    }

    private func commitIfValid() {
        guard canSave else { return }
        onSave(trimmedLabel, trimmedCwd, command, splitDirection)
    }
}

#Preview {
    WorkspacePaneEditRow(
        onSave: { _, _, _, _ in },
        onCancel: {}
    )
    .padding()
    .frame(width: 300)
    .background(DevtailTokens.Colors.popoverBackground)
}
