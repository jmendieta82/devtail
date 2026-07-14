//
//  SidebarSortMode.swift
//  Devtail
//
//  Persisted in UserDefaults as its rawValue string.
//  Key: com.jamodev.Devtail.sidebarSortMode
//

import Foundation

enum SidebarSortMode: String, CaseIterable {
    /// Most recently launched first; unlaunched projects at the bottom,
    /// sorted alphabetically among themselves.
    case recency     = "recency"
    /// Alphabetical by project name, case-insensitive.
    case alphabetical = "alphabetical"

    static let userDefaultsKey = "com.jamodev.Devtail.sidebarSortMode"

    static func load() -> SidebarSortMode {
        guard let raw = UserDefaults.standard.string(forKey: userDefaultsKey),
              let mode = SidebarSortMode(rawValue: raw) else {
            return .recency
        }
        return mode
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: SidebarSortMode.userDefaultsKey)
    }
}
