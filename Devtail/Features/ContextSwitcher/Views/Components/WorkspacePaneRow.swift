//
//  WorkspacePaneRow.swift
//  Devtail
//
//  Read-only row displaying a workspace pane. Hover reveals edit/delete
//  action icons — no more "edit mode" toggle on the parent. Shows label,
//  stack (if set), relativeCwd, command and split direction badge.
//

import SwiftUI

struct WorkspacePaneRow: View {
    let pane: WorkspacePane
    let onEditTap: () -> Void
    let onDelete: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
                HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                    Text(pane.label)
                        .font(DevtailTokens.Typography.bodySmall)
                        .foregroundStyle(DevtailTokens.Colors.textPrimary)
                        .lineLimit(1)
                    if let stack = pane.stack, !stack.isEmpty {
                        Text(stack)
                            .font(DevtailTokens.Typography.captionSmall)
                            .foregroundStyle(DevtailTokens.Colors.textTertiary)
                            .padding(.horizontal, DevtailTokens.Spacing.gapSmall)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: DevtailTokens.Radius.badge)
                                    .fill(DevtailTokens.Colors.inputBackground)
                            )
                    }
                }
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

            if isHovering {
                hoverActions
            } else if pane.splitDirection != "none" {
                splitDirectionBadge
            }
        }
        .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
        .background(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.linkChip)
                .fill(isHovering
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
        .contextMenu {
            Button {
                onEditTap()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var hoverActions: some View {
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            Button {
                onEditTap()
            } label: {
                Image(systemName: "pencil")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Edit pane")

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Delete pane")
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
