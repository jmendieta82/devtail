//
//  QuickCommand.swift
//  Devtail
//
//  A shell command associated with a project (e.g. "npm run dev", "make test").
//  Executed via NSWorkspace + Terminal.app due to App Sandbox restrictions.
//

import Foundation
import SwiftData

@Model
final class QuickCommand {
    @Attribute(.unique) var id: UUID
    var label: String
    var command: String
    var symbolName: String
    var sortOrder: Int

    var project: Project?

    init(
        id: UUID = UUID(),
        label: String,
        command: String,
        symbolName: String = "terminal",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.label = label
        self.command = command
        self.symbolName = symbolName
        self.sortOrder = sortOrder
    }
}
