//
//  ProjectColor.swift
//  Devtail
//
//  Closed set of colors a user can assign to a project. Each case maps to
//  a design token in `DevtailTokens.Colors.project*`.
//

import SwiftUI

enum ProjectColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case green
    case blue
    case orange
    case purple
    case pink
    case amber
    case gray

    var id: String { rawValue }

    /// Concrete `Color` from the design system.
    var color: Color {
        switch self {
        case .green:  return DevtailTokens.Colors.projectGreen
        case .blue:   return DevtailTokens.Colors.projectBlue
        case .orange: return DevtailTokens.Colors.projectOrange
        case .purple: return DevtailTokens.Colors.projectPurple
        case .pink:   return DevtailTokens.Colors.projectPink
        case .amber:  return DevtailTokens.Colors.projectAmber
        case .gray:   return DevtailTokens.Colors.projectGray
        }
    }
}
