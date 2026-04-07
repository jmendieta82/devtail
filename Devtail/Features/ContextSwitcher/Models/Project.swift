//
//  Project.swift
//  Devtail
//
//  Core domain model: a development project the user works on.
//

import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var symbolName: String
    var projectDescription: String
    var stack: String
    var environment: String
    var isActive: Bool
    var createdAt: Date

    /// Security-scoped bookmark to the project's root directory on disk.
    /// Required because App Sandbox blocks arbitrary filesystem access —
    /// the user picks the directory once via NSOpenPanel, we serialize the
    /// bookmark, and resolve it later when launching a terminal there.
    var directoryBookmark: Data?

    @Relationship(deleteRule: .cascade, inverse: \QuickLink.project)
    var quickLinks: [QuickLink] = []

    @Relationship(deleteRule: .cascade, inverse: \QuickCommand.project)
    var quickCommands: [QuickCommand] = []

    @Relationship(deleteRule: .cascade, inverse: \CloudAccount.project)
    var cloudAccounts: [CloudAccount] = []

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#5E5CE6",
        symbolName: String = "folder.fill",
        projectDescription: String = "",
        stack: String = "",
        environment: String = "",
        isActive: Bool = false,
        directoryBookmark: Data? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.symbolName = symbolName
        self.projectDescription = projectDescription
        self.stack = stack
        self.environment = environment
        self.isActive = isActive
        self.directoryBookmark = directoryBookmark
        self.createdAt = createdAt
    }
}
