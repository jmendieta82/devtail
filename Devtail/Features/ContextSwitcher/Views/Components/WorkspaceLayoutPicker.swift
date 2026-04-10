//
//  WorkspaceLayoutPicker.swift
//  Devtail
//
//  Horizontal row of 4 layout thumbnail buttons. The currently-selected
//  layout shows an accent-colored ring. Tapping any thumbnail fires
//  onChange immediately — no confirmation required.
//

import SwiftUI

@MainActor
struct WorkspaceLayoutPicker: View {
    @Binding var layout: WorkspaceLayout
    var onChange: (WorkspaceLayout) -> Void

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapMedium) {
            ForEach(WorkspaceLayout.allCases, id: \.rawValue) { candidate in
                Button {
                    layout = candidate
                    onChange(candidate)
                } label: {
                    WorkspaceLayoutThumbnail(
                        layout: candidate,
                        size: CGSize(width: 60, height: 40)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(
                                layout == candidate
                                    ? DevtailTokens.Colors.accentGreen
                                    : DevtailTokens.Colors.borderSubtle,
                                lineWidth: layout == candidate ? 2 : DevtailTokens.BorderWidth.default
                            )
                    )
                }
                .buttonStyle(.plain)
                .help(candidate.displayName)
                .cursor(.pointingHand)
            }
        }
    }
}

private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { isHovering in
            if isHovering { cursor.push() } else { NSCursor.pop() }
        }
    }
}

#Preview {
    @Previewable @State var selection: WorkspaceLayout = .halvesVertical
    WorkspaceLayoutPicker(layout: $selection, onChange: { _ in })
        .padding()
        .background(DevtailTokens.Colors.popoverBackground)
}
