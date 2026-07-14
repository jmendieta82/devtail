//
//  FrontendStackDefaults.swift
//  Devtail
//
//  Static policy table mapping detected stack labels to frontend defaults.
//  Consumed by WorkspacePaneEditRow to pre-fill the isFrontend toggle and
//  localhostUrl field. Lives in Core/Shell because BrowserLauncher (the
//  consumer at launch time) is in the same layer.
//

import Foundation

enum FrontendStackDefaults {
    /// Labels that pre-check the "Frontend workspace" toggle when detected.
    static let frontendLabels: Set<String> = ["React", "Next.js", "Angular", "Vue"]

    /// Fallback for unknown or backend stacks when the user manually toggles on.
    static let genericDefaultURL = "http://localhost:3000"

    private static let urlByLabel: [String: String] = [
        "Angular": "http://localhost:4200",
        "React":   "http://localhost:3000",
        "Next.js": "http://localhost:3000",
        "Vue":     "http://localhost:5173"
    ]

    static func isFrontend(label: String?) -> Bool {
        guard let label else { return false }
        return frontendLabels.contains(label)
    }

    static func defaultURL(forLabel label: String?) -> String {
        guard let label, let url = urlByLabel[label] else { return genericDefaultURL }
        return url
    }
}
