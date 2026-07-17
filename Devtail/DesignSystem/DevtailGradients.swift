//
//  DevtailGradients.swift
//  Devtail
//
//  Shared gradient definitions used as window/popover backgrounds.
//

import SwiftUI

enum DevtailGradients {
    /// Dark gradient backdrop shared by the app's windows and the menu bar
    /// popover. Top-left to bottom-right: near-black → deep indigo → accent
    /// teal. Gives the app a distinctive, futuristic look without relying on
    /// the system's translucent material (which picks up desktop noise).
    static var appBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.09),
                Color(red: 0.08, green: 0.09, blue: 0.18),
                Color(red: 0.06, green: 0.14, blue: 0.22)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
