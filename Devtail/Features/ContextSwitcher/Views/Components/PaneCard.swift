import SwiftUI

/// Spacious pane card for the dashboard.
/// Shows label, badges, directory, command, and always-visible action buttons.
struct PaneCard: View {
    let pane: WorkspacePane
    var branch: String? = nil
    var slotLabel: String? = nil
    var canDelete: Bool = true
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapMedium) {
            // Line 1: Label + badges
            HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                Text(pane.label)
                    .font(DevtailTokens.Typography.bodySemibold)
                    .foregroundStyle(DevtailTokens.Colors.textPrimary)
                    .lineLimit(1)

                Spacer()

                if let slotLabel {
                    Text(slotLabel)
                        .font(DevtailTokens.Typography.captionSmall)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                        .padding(.horizontal, DevtailTokens.Spacing.gapSmall)
                        .padding(.vertical, 1)
                }

                if let branch {
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .font(DevtailTokens.Typography.captionSmall)
                        .foregroundStyle(DevtailTokens.Colors.accentGreen)
                        .padding(.horizontal, DevtailTokens.Spacing.gapSmall)
                        .padding(.vertical, 1)
                }

                if let stack = pane.stack, !stack.isEmpty {
                    Text(stack)
                        .font(DevtailTokens.Typography.captionSmall)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                        .padding(.horizontal, DevtailTokens.Spacing.gapSmall)
                        .padding(.vertical, 1)
                }

                if let env = pane.environment {
                    EnvironmentPill(environment: env, compact: true)
                }
            }

            // Line 2: Directory
            Text(pane.relativeCwd)
                .font(DevtailTokens.Typography.mono)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
                .lineLimit(1)

            // Line 3: Command (if present)
            if !pane.command.isEmpty {
                Text(pane.command)
                    .font(DevtailTokens.Typography.mono)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .lineLimit(1)
            }

            // Actions — always visible
            HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                Spacer()
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textSecondary)
                        .padding(.horizontal, DevtailTokens.Spacing.gapLarge)
                        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
                        .overlay {
                            RoundedRectangle(cornerRadius: DevtailTokens.Radius.chip)
                                .stroke(
                                    DevtailTokens.Colors.borderSubtle,
                                    lineWidth: DevtailTokens.BorderWidth.default
                                )
                        }
                }
                .buttonStyle(.plain)
                .help("Edit pane settings")

                Button(action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(
                            canDelete
                                ? DevtailTokens.Colors.textSecondary
                                : DevtailTokens.Colors.textDisabled
                        )
                        .padding(.horizontal, DevtailTokens.Spacing.gapLarge)
                        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
                        .overlay {
                            RoundedRectangle(cornerRadius: DevtailTokens.Radius.chip)
                                .stroke(
                                    DevtailTokens.Colors.borderSubtle,
                                    lineWidth: DevtailTokens.BorderWidth.default
                                )
                        }
                }
                .buttonStyle(.plain)
                .disabled(!canDelete)
                .help(canDelete ? "Remove this pane" : "Cannot delete the last pane")
            }
        }
        .padding(.horizontal, DevtailTokens.Spacing.cardPadding)
        .padding(.vertical, DevtailTokens.Spacing.gapDefault)
        .glassEffect(in: RoundedRectangle(cornerRadius: DevtailTokens.Radius.card))
    }
}
