//
//  ColorDot.swift
//  Devtail
//
//  Atom: a single project-color dot. Used by the project row, the dashboard
//  sidebar (future), and indirectly by the color picker (which uses its own
//  custom layout).
//

import SwiftUI

struct ColorDot: View {
    let color: ProjectColor
    var size: CGFloat = DevtailTokens.Sizes.projectDot

    var body: some View {
        Circle()
            .fill(color.color)
            .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: DevtailTokens.Spacing.gapMedium) {
        ForEach(ProjectColor.allCases) { color in
            ColorDot(color: color)
        }
    }
    .padding()
    .background(DevtailTokens.Colors.popoverBackground)
}
