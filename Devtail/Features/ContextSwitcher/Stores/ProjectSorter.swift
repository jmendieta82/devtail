//
//  ProjectSorter.swift
//  Devtail
//
//  Pure sort function for the project list, shared by the popover header's
//  sort menu.
//
//  Concurrency: marked Sendable. No state, no MainActor-isolated data
//  touched directly — Project instances flow in from the caller.
//

import Foundation

struct ProjectSorter: Sendable {

    init() {}

    /// Orders `projects` per `mode`:
    /// - `.alphabetical`: case-insensitive name ascending.
    /// - `.recency`: most recently launched first; projects that have
    ///   never been launched sink to the bottom, sorted alphabetically
    ///   among themselves.
    func sort(_ projects: [Project], mode: SidebarSortMode) -> [Project] {
        switch mode {
        case .alphabetical:
            return projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .recency:
            return projects.sorted { a, b in
                switch (a.lastLaunchedAt, b.lastLaunchedAt) {
                case let (.some(dateA), .some(dateB)):
                    return dateA > dateB
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }
            }
        }
    }
}
