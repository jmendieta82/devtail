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
    /// Optional git branch label resolved by the parent panel via
    /// `GitBranchDetector`. Computed in the panel — not in the row —
    /// because the row does not know the absolute project root and
    /// shouldn't reach into the filesystem from a SwiftUI body. `nil`
    /// when the pane's folder is not inside a git repo.
    var branch: String? = nil
    /// When true, hover actions and the context menu are suppressed.
    /// The row still highlights on hover so the user gets feedback,
    /// but no edit/delete affordances are exposed.
    var isReadOnly: Bool = false
    let onEditTap: () -> Void
    let onDelete: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        rowContent
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
            .applyContextMenuIfNeeded(
                isEnabled: !isReadOnly,
                onEdit: onEditTap,
                onDelete: onDelete
            )
    }

    private var rowContent: some View {
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
                    if let env = pane.environment {
                        // Compact pill so it sits cleanly between the
                        // stack and branch badges without dominating them.
                        EnvironmentPill(environment: env, compact: true)
                    }
                    if let branch, !branch.isEmpty {
                        // Branch badge sits next to the stack badge.
                        // Leading icon makes the meaning unambiguous —
                        // a bare label like "main" could be confused
                        // with a stack name.
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 9, weight: .medium))
                            Text(branch)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .font(DevtailTokens.Typography.captionSmall)
                        .foregroundStyle(DevtailTokens.Colors.accentGreen)
                        .padding(.horizontal, DevtailTokens.Spacing.gapSmall)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: DevtailTokens.Radius.badge)
                                .fill(DevtailTokens.Colors.accentGreen.opacity(0.12))
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

            if isHovering && !isReadOnly {
                hoverActions
            } else if pane.splitDirection != "none" {
                splitDirectionBadge
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

private extension View {
    /// Attaches a context menu with Edit/Delete actions when `isEnabled`
    /// is true; otherwise returns the view untouched. Extracted as an
    /// extension so the call site reads as a single modifier instead
    /// of inlining a verbose `if` branch in the view body. The reason
    /// we condition the WHOLE modifier (instead of an empty body inside
    /// `.contextMenu`) is that an empty context menu still claims the
    /// right-click and renders an empty popup — only skipping the
    /// modifier altogether truly disables it.
    @ViewBuilder
    func applyContextMenuIfNeeded(
        isEnabled: Bool,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        if isEnabled {
            self.contextMenu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            self
        }
    }
}
