//
//  QuickLinkEditRow.swift
//  Devtail
//
//  Inline edit row for creating or updating a QuickLink. Two TextFields
//  (label + URL) with URL normalization on submit and focus-loss, a
//  Save button (disabled when invalid), and a Cancel button.
//

import SwiftUI

struct QuickLinkEditRow: View {
    let initialLabel: String
    let initialURL: String
    let onSave: (_ label: String, _ url: String) -> Void
    let onCancel: () -> Void

    @State private var label: String
    @State private var url: String
    @State private var urlIsInvalid: Bool = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case label, url
    }

    init(
        initialLabel: String = "",
        initialURL: String = "",
        onSave: @escaping (String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialLabel = initialLabel
        self.initialURL = initialURL
        self.onSave = onSave
        self.onCancel = onCancel
        _label = State(initialValue: initialLabel)
        _url = State(initialValue: initialURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
            TextField("Label", text: $label, prompt: Text("GitHub"))
                .textFieldStyle(.plain)
                .font(DevtailTokens.Typography.bodySmall)
                .foregroundStyle(DevtailTokens.Colors.textPrimary)
                .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
                .padding(.vertical, DevtailTokens.Spacing.gapSmall)
                .background(
                    RoundedRectangle(cornerRadius: DevtailTokens.Radius.searchField)
                        .fill(Color.black.opacity(0.25))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DevtailTokens.Radius.searchField)
                        .stroke(DevtailTokens.Colors.borderSubtle,
                                lineWidth: DevtailTokens.BorderWidth.default)
                )
                .focused($focusedField, equals: .label)
                .onSubmit { focusedField = .url }

            TextField("URL", text: $url, prompt: Text("https://github.com"))
                .textFieldStyle(.plain)
                .font(DevtailTokens.Typography.bodySmall)
                .foregroundStyle(DevtailTokens.Colors.textPrimary)
                .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
                .padding(.vertical, DevtailTokens.Spacing.gapSmall)
                .background(
                    RoundedRectangle(cornerRadius: DevtailTokens.Radius.searchField)
                        .fill(Color.black.opacity(0.25))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DevtailTokens.Radius.searchField)
                        .stroke(urlIsInvalid
                                ? Color.red.opacity(0.8)
                                : DevtailTokens.Colors.borderSubtle,
                                lineWidth: urlIsInvalid
                                    ? 1
                                    : DevtailTokens.BorderWidth.default)
                )
                .focused($focusedField, equals: .url)
                .onSubmit { commitURLAndSave() }
                .onChange(of: focusedField) { _, newField in
                    if newField != .url {
                        normalizeURLField()
                    }
                }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Save", action: commitURLAndSave)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!canSave)
            }
        }
    }

    private var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedLabel.isEmpty && normalizeURL(url) != nil
    }

    private func normalizeURLField() {
        if let normalized = normalizeURL(url) {
            url = normalized
            urlIsInvalid = false
        } else if !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            urlIsInvalid = true
        }
    }

    private func commitURLAndSave() {
        normalizeURLField()
        guard canSave else { return }
        onSave(trimmedLabel, url)
    }
}

#Preview {
    QuickLinkEditRow(
        onSave: { _, _ in },
        onCancel: {}
    )
    .padding()
    .frame(width: 300)
    .background(DevtailTokens.Colors.popoverBackground)
}
