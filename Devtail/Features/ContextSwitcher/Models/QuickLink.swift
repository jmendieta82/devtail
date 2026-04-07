//
//  QuickLink.swift
//  Devtail
//
//  A configurable URL associated with a project (staging, prod, repo, CI, etc.).
//

import Foundation
import SwiftData

@Model
final class QuickLink {
    @Attribute(.unique) var id: UUID
    var label: String
    var url: String
    var symbolName: String
    var sortOrder: Int

    var project: Project?

    init(
        id: UUID = UUID(),
        label: String,
        url: String,
        symbolName: String = "link",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.label = label
        self.url = url
        self.symbolName = symbolName
        self.sortOrder = sortOrder
    }
}
