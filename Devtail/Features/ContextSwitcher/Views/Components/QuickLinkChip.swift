//
//  QuickLinkChip.swift
//  Devtail
//
//  Atom: a quick link chip. View mode opens the URL on tap. Edit mode shows
//  the label with a delete button and routes taps to the edit closure.
//

import SwiftUI

struct QuickLinkChip: View {
    let quickLink: QuickLink
    let isEditing: Bool
    let onEditTap: () -> Void
    let onDelete: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapMedium) {
            Image(systemName: iconName)
                .font(DevtailTokens.Typography.bodySmall)
                .foregroundStyle(DevtailTokens.Colors.accentPrimary)
                .frame(width: 14)

            Text(quickLink.label)
                .font(DevtailTokens.Typography.bodySmall)
                .foregroundStyle(DevtailTokens.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            if isEditing {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(DevtailTokens.Typography.captionSmall)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DevtailTokens.Spacing.gapLarge)
        .padding(.vertical, DevtailTokens.Spacing.gapMedium)
        .background(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.linkChip)
                .fill(DevtailTokens.Colors.accentPrimary.opacity(isHovering ? 0.18 : 0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.linkChip)
                .stroke(DevtailTokens.Colors.accentPrimary.opacity(0.25),
                        lineWidth: DevtailTokens.BorderWidth.default)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture {
            if isEditing {
                onEditTap()
            } else if let url = URL(string: quickLink.url) {
                openURL(url)
            }
        }
    }

    /// Icon is derived from the URL's category, so it always matches the
    /// section header the chip lives under.
    private var iconName: String {
        QuickLinkCategory.classify(urlString: quickLink.url).iconName
    }
}

#Preview("View mode") {
    let chip: QuickLinkChip = {
        let project = Project(name: "Preview", color: .blue)
        let link = QuickLink(label: "GitHub", url: "https://github.com", order: 0, project: project)
        return QuickLinkChip(
            quickLink: link,
            isEditing: false,
            onEditTap: {},
            onDelete: {}
        )
    }()
    chip
        .padding()
        .background(DevtailTokens.Colors.popoverBackground)
}

#Preview("Edit mode") {
    let chip: QuickLinkChip = {
        let project = Project(name: "Preview", color: .blue)
        let link = QuickLink(label: "GitHub", url: "https://github.com", order: 0, project: project)
        return QuickLinkChip(
            quickLink: link,
            isEditing: true,
            onEditTap: {},
            onDelete: {}
        )
    }()
    chip
        .padding()
        .background(DevtailTokens.Colors.popoverBackground)
}
