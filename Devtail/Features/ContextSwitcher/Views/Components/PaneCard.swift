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
            HStack {
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .frame(
                            width: DevtailTokens.Sizes.actionButtonSize,
                            height: DevtailTokens.Sizes.actionButtonSize
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
                .help("Edit pane settings")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .frame(
                            width: DevtailTokens.Sizes.actionButtonSize,
                            height: DevtailTokens.Sizes.actionButtonSize
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(canDelete ? DevtailTokens.Colors.textSecondary : DevtailTokens.Colors.textDisabled)
                .disabled(!canDelete)
                .help(canDelete ? "Remove this pane" : "Cannot delete the last pane")
            }
        }
        .padding(.horizontal, DevtailTokens.Spacing.cardPadding)
        .padding(.vertical, DevtailTokens.Spacing.gapDefault)
        .glassEffect()
    }
}
