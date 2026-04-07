//
//  ProjectEnvironment.swift
//  Devtail
//
//  Environment a project is pointing at. Closed set — freelancers can
//  express their setup with these three canonical values.
//

import Foundation

enum ProjectEnvironment: String, Codable, CaseIterable, Identifiable, Sendable {
    case dev
    case staging
    case prod

    var id: String { rawValue }

    /// Short display label shown in the environment badge.
    var displayName: String {
        rawValue
    }
}
