//
//  QuickLink.swift
//  Devtail
//
//  SwiftData model for a per-project quick link (label + URL).
//  Many-to-one relationship with Project (cascade delete handled
//  via the inverse relationship declared on Project).
//

import Foundation
import SwiftData

@Model
final class QuickLink {
    @Attribute(.unique) var id: UUID
    var label: String
    var url: String
    var order: Int
    var createdAt: Date
    var updatedAt: Date

    var project: Project?

    init(label: String, url: String, order: Int, project: Project) {
        self.id = UUID()
        self.label = label
        self.url = url
        self.order = order
        self.project = project
        let now = Date.now
        self.createdAt = now
        self.updatedAt = now
    }
}
