//
//  PersistenceController.swift
//  Devtail
//
//  Centralized SwiftData ModelContainer setup.
//

import Foundation
import SwiftData

enum PersistenceController {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([
            Project.self,
            QuickLink.self,
            QuickCommand.self,
            CloudAccount.self,
            CostSnapshot.self,
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
