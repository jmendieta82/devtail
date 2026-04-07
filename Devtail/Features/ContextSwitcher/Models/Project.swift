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
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(name: String, notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.notes = notes
        let now = Date.now
        self.createdAt = now
        self.updatedAt = now
    }
}
