//
//  PersistenceController.swift
//  Devtail
//
//  Centralized SwiftData ModelContainer setup.
//

import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.jamodev.Devtail", category: "persistence")

enum PersistenceController {
    // schema v2: layout-picker
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([
            Project.self,
            QuickLink.self,
            WorkspacePane.self,
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logger.fault("Failed to initialize persistent ModelContainer: \(error.localizedDescription, privacy: .public). Falling back to in-memory store.")
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // If even the in-memory fallback fails, the process has no viable path.
            return try! ModelContainer(for: schema, configurations: [fallbackConfig])
        }
    }
}
