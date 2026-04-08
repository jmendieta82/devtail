//
//  WorkspacePaneRow.swift
//  Devtail
//
//  Read-only row displaying a workspace pane. In edit mode shows a delete
//  button and routes taps to the edit closure.
//

import SwiftUI

struct WorkspacePaneRow: View {
    let pane: WorkspacePane
    let isEditing: Bool
    let onEditTap: () -> Void
    let onDelete: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
                Text(pane.label)
                    .font(DevtailTokens.Typography.bodySmall)
                    .foregroundStyle(DevtailTokens.Colors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                    Text(pane.relativeCwd)
                        .font(DevtailTokens.Typography.monoSmall)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                        .lineLimit(1)
                    if !pane.command.isEmpty {
                        Text("·")
                            .font(DevtailTokens.Typography.caption)
                            .foregroundStyle(DevtailTokens.Colors.textMuted)
                        Text(pane.command)
                            .font(DevtailTokens.Typography.monoSmall)
                            .foregroundStyle(DevtailTokens.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: DevtailTokens.Spacing.gapSmall)

            if !isEditing && pane.splitDirection != "none" {
                splitDirectionBadge
            }

            if isEditing {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(DevtailTokens.Typography.captionSmall)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Delete pane")
            }
        }
        .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
        .background(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.linkChip)
                .fill(isHovering && isEditing
                      ? DevtailTokens.Colors.hoverState
                      : DevtailTokens.Colors.pill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.linkChip)
                .stroke(DevtailTokens.Colors.borderSubtle,
                        lineWidth: DevtailTokens.BorderWidth.default)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture {
            if isEditing {
                onEditTap()
            }
        }
    }

    private var splitDirectionBadge: some View {
        Text(pane.splitDirection == "right" ? "→" : "↓")
            .font(DevtailTokens.Typography.captionSmall)
            .foregroundStyle(DevtailTokens.Colors.textMuted)
            .padding(.horizontal, DevtailTokens.Spacing.gapSmall)
            .padding(.vertical, DevtailTokens.Spacing.gapTiny)
            .background(
                RoundedRectangle(cornerRadius: DevtailTokens.Radius.badge)
                    .fill(DevtailTokens.Colors.inputBackground)
            )
    }
}
