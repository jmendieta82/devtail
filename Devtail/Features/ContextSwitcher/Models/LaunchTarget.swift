//
//  LaunchTarget.swift
//  Devtail
//
//  Per-project preference for how the Ghostty workspace is opened:
//  auto (runtime window-count check), new tab in the front window,
//  or always a new OS window.
//

import Foundation

enum LaunchTarget: String, Codable, CaseIterable, Identifiable {
    case auto
    case newTab
    case newWindow

    var id: String { rawValue }

    /// User-facing label shown in the project form picker.
    var label: String {
        switch self {
        case .auto:      "Auto (use existing window if any)"
        case .newTab:    "New tab"
        case .newWindow: "New window"
        }
    }
}
