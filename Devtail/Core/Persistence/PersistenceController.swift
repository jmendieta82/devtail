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
    // schema v3: frontend fields (isFrontend, localhostUrl) moved to WorkspacePane — lightweight migration, no VersionedSchema needed
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([
            Project.self,
            QuickLink.self,
            WorkspacePane.self,
        ])

        // Unsandboxed, SwiftData's implicit location is the SHARED
        // ~/Library/Application Support/default.store — a namespace any app
        // can collide on (and did: a foreign default.store from another tool
        // was silently opened after the sandbox was dropped). Pin our own
        // explicit store file instead, migrating the old sandbox-container
        // store on first launch so existing projects survive.
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            let storeURL = devtailStoreURL()
            migrateSandboxStoreIfNeeded(to: storeURL)
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        }

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logger.fault("Failed to initialize persistent ModelContainer: \(error.localizedDescription, privacy: .public). Falling back to in-memory store.")
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // If even the in-memory fallback fails, the process has no viable path.
            return try! ModelContainer(for: schema, configurations: [fallbackConfig])
        }
    }

    /// Devtail's own store file: ~/Library/Application Support/Devtail/Devtail.store.
    /// Never the shared implicit default.store.
    private static func devtailStoreURL() -> URL {
        let dir = URL.applicationSupportDirectory.appendingPathComponent("Devtail", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("Devtail.store")
    }

    /// One-shot migration from the App Sandbox era: the sandboxed app kept its
    /// store inside ~/Library/Containers/<bundle-id>/…/default.store. If our
    /// new store doesn't exist yet and the container one does, copy it (plus
    /// SQLite sidecars) so the user's projects survive the sandbox removal.
    /// Best-effort: on any failure the app simply starts with an empty store.
    private static func migrateSandboxStoreIfNeeded(to destination: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: destination.path) else { return }

        let containerStore = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.jamodev.Devtail/Data/Library/Application Support/default.store")
        guard fm.fileExists(atPath: containerStore.path) else { return }

        for suffix in ["", "-shm", "-wal"] {
            let source = URL(fileURLWithPath: containerStore.path + suffix)
            let target = URL(fileURLWithPath: destination.path + suffix)
            guard fm.fileExists(atPath: source.path) else { continue }
            do {
                try fm.copyItem(at: source, to: target)
            } catch {
                logger.fault("Sandbox store migration failed for \(source.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        logger.info("Migrated sandbox-era store to \(destination.path, privacy: .public)")
    }
}
