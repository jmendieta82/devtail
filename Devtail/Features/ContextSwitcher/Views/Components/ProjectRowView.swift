//
//  ProjectRowView.swift
//  Devtail
//
//  Reusable project row. Accepts loose values (not a Project instance) so it
//  can be reused as the live preview inside ProjectFormView. Hover state is
//  local to each row to avoid re-rendering the whole list on hover changes.
//

import SwiftUI

struct ProjectRowView: View {
    let name: String
    let color: ProjectColor
    let environment: ProjectEnvironment
    let stack: String?
    let isSelected: Bool
    var isInteractive: Bool = true
    var onTap: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapMedium) {
            ColorDot(color: color)
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
                Text(name)
                    .font(DevtailTokens.Typography.bodyDefault)
                    .foregroundStyle(DevtailTokens.Colors.textPrimary)
                    .lineLimit(1)
                if let stack, !stack.isEmpty {
                    Text(stack)
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textMuted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: DevtailTokens.Spacing.gapSmall)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.accentGreen)
            }
            EnvironmentPill(environment: environment)
            if isInteractive && isHovered {
                rowActions
            }
        }
        .padding(.horizontal, DevtailTokens.Spacing.cardPadding)
        .padding(.vertical, DevtailTokens.Spacing.gapMedium)
        .background(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.projectRow)
                .fill(rowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.projectRow)
                .stroke(rowBorder, lineWidth: DevtailTokens.BorderWidth.default)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            guard isInteractive else { return }
            isHovered = hovering
        }
        .onTapGesture {
            guard isInteractive else { return }
            onTap?()
        }
        .contextMenu {
            if isInteractive {
                menuContent
            }
        }
    }

    @ViewBuilder
    private var rowActions: some View {
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            Button {
                onEdit?()
            } label: {
                Image(systemName: "pencil")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Edit project")

            Menu {
                menuContent
            } label: {
                Image(systemName: "ellipsis")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
                    .frame(width: 20, height: 20)
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .frame(width: 20, height: 20)
            .help("More options")
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        Button {
            onEdit?()
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        Button(role: .destructive) {
            onDelete?()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.activeProjectBg
        }
        if isHovered {
            return DevtailTokens.Colors.hoverState
        }
        return Color.clear
    }

    private var rowBorder: Color {
        isSelected ? Color.activeProjectBorder : Color.clear
    }
}

#Preview("States") {
    VStack(spacing: DevtailTokens.Spacing.gapSmall) {
        ProjectRowView(
            name: "Devtail",
            color: .green,
            environment: .dev,
            stack: "Swift + SwiftUI",
            isSelected: false
        )
        ProjectRowView(
            name: "Side Project",
            color: .blue,
            environment: .staging,
            stack: "TypeScript",
            isSelected: true
        )
        ProjectRowView(
            name: "Pixel",
            color: .purple,
            environment: .prod,
            stack: nil,
            isSelected: false
        )
    }
    .padding()
    .frame(width: DevtailTokens.Sizes.popoverWidth)
    .background(DevtailTokens.Colors.popoverBackground)
}

#Preview("Preview mode (non-interactive)") {
    ProjectRowView(
        name: "Live preview",
        color: .amber,
        environment: .prod,
        stack: "Rust",
        isSelected: false,
        isInteractive: false
    )
    .padding()
    .frame(width: DevtailTokens.Sizes.popoverWidth)
    .background(DevtailTokens.Colors.popoverBackground)
}
