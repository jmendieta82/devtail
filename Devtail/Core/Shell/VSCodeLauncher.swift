//
//  VSCodeLauncher.swift
//  Devtail
//
//  Sandbox-safe launcher that opens a project directory in Visual Studio Code
//  using NSWorkspace.open(_:withApplicationAt:configuration:) — no Process,
//  no `code` CLI, no extra entitlements.
//

import AppKit
import Foundation

// MARK: - Error

enum VSCodeLauncherError: Error, Equatable {
    case projectHasNoDirectory
    case vscodeNotInstalled
    case openFailed(String)

    static func == (lhs: VSCodeLauncherError, rhs: VSCodeLauncherError) -> Bool {
        switch (lhs, rhs) {
        case (.projectHasNoDirectory, .projectHasNoDirectory): return true
        case (.vscodeNotInstalled, .vscodeNotInstalled): return true
        case (.openFailed(let a), .openFailed(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Protocol

@MainActor
protocol VSCodeLauncherProtocol {
    /// Opens `directoryPath` in Visual Studio Code. The optional
    /// `bookmark` is a security-scoped bookmark captured when the user
    /// originally picked the folder via NSOpenPanel — required under App
    /// Sandbox so the folder URL can be handed off to an external app
    /// without triggering "no tiene permiso para abrir X".
    func open(directoryPath: String, bookmark: Data?) async throws
}

// MARK: - Implementation

@MainActor
struct VSCodeLauncher: VSCodeLauncherProtocol {
    private static let bundleID = "com.microsoft.VSCode"

    /// Seam for unit tests: inject `{ _ in nil }` to exercise the
    /// `vscodeNotInstalled` branch without touching NSWorkspace.
    var resolveAppURL: (String) -> URL? = { bundleID in
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    func open(directoryPath: String, bookmark: Data?) async throws {
        let trimmed = directoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VSCodeLauncherError.projectHasNoDirectory }

        guard let appURL = resolveAppURL(Self.bundleID) else {
            throw VSCodeLauncherError.vscodeNotInstalled
        }

        // Under App Sandbox, the folder URL must come from a security-scoped
        // bookmark so LaunchServices can forward the access right to VSCode.
        // A raw fileURL built from a path string lacks that right and causes
        // the "Devtail no tiene permiso para abrir X" dialog.
        let resolvedURL: URL
        let scopedURL: URL?
        if let bookmark {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmark,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                resolvedURL = url
                scopedURL = url.startAccessingSecurityScopedResource() ? url : nil
            } catch {
                throw VSCodeLauncherError.openFailed(
                    "Cannot resolve security-scoped bookmark for \(trimmed): \(error.localizedDescription)"
                )
            }
        } else {
            resolvedURL = URL(fileURLWithPath: trimmed, isDirectory: true)
            scopedURL = nil
        }
        defer { scopedURL?.stopAccessingSecurityScopedResource() }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        do {
            _ = try await NSWorkspace.shared.open(
                [resolvedURL],
                withApplicationAt: appURL,
                configuration: config
            )
        } catch {
            throw VSCodeLauncherError.openFailed(error.localizedDescription)
        }
    }
}
