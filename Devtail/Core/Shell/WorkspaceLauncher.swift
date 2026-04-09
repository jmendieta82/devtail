//
//  WorkspaceLauncher.swift
//  Devtail
//
//  Opens Ghostty at a project's root directory and drives it via Ghostty's
//  native AppleScript dictionary (available since Ghostty 1.3) to recreate
//  the project's WorkspacePane layout (splits + per-pane cd + command).
//
//  Sandbox-safe: uses NSAppleScript with the apple-events entitlement.
//  No System Events / keystroke simulation — all commands go through the
//  native Ghostty dictionary verbs (new window, split, input text, send key).
//

import AppKit
import Foundation

// MARK: - Error

enum WorkspaceLauncherError: Error, Equatable {
    case projectHasNoDirectory
    case ghosttyNotInstalled
    case automationPermissionDenied
    case appleScriptFailed(String)

    static func == (lhs: WorkspaceLauncherError, rhs: WorkspaceLauncherError) -> Bool {
        switch (lhs, rhs) {
        case (.projectHasNoDirectory, .projectHasNoDirectory): return true
        case (.ghosttyNotInstalled, .ghosttyNotInstalled): return true
        case (.automationPermissionDenied, .automationPermissionDenied): return true
        case (.appleScriptFailed(let a), .appleScriptFailed(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Protocol

@MainActor
protocol WorkspaceLauncherProtocol {
    func launch(project: Project, panes: [WorkspacePane]) async throws
}

// MARK: - Script builder (file scope, testable)

/// Builds the AppleScript source that drives Ghostty using its native
/// AppleScript dictionary (Ghostty 1.3+).
///
/// Algorithm:
///   1. Activate Ghostty (launches it if not running).
///   2. Create a surface configuration with `initial working directory`
///      set to the resolved absolute path of pane 0, then `new window`.
///   3. Capture the first terminal reference from the new window.
///   4. For every subsequent pane:
///      - Create a configuration with its absolute cwd
///      - `split` from the previous terminal in the requested direction
///      - Send `cd <abs>` + enter as a defensive fallback (the preview API
///        may or may not honor `initial working directory` on splits)
///      - Send the pane command + enter (if non-empty)
///   5. Focus pane 0 at the end so the user lands on the main pane.
///
/// - Parameters:
///   - directoryPath: The project's absolute root path.
///   - panes: The WorkspacePane list, already sorted by `order` (caller
///     must pre-sort).
/// - Returns: AppleScript source code ready for NSAppleScript.
func buildLaunchScript(directoryPath: String, panes: [WorkspacePane]) -> String {
    var lines: [String] = []

    lines.append("tell application \"Ghostty\"")
    lines.append("    activate")

    // Empty case: just activate the app, no windows spawned.
    if panes.isEmpty {
        lines.append("end tell")
        return lines.joined(separator: "\n")
    }

    // Pane 0 — the initial window with the project root cwd.
    let pane0 = panes[0]
    let pane0Path = resolvedPath(rootPath: directoryPath, relativeCwd: pane0.relativeCwd)

    lines.append("    set mainCfg to new surface configuration")
    lines.append("    set initial working directory of mainCfg to \"\(pane0Path)\"")
    lines.append("    set win to new window with configuration mainCfg")
    lines.append("    set term0 to focused terminal of selected tab of win")

    // Pane 0 command (optional).
    let pane0Cmd = pane0.command.trimmingCharacters(in: .whitespacesAndNewlines)
    if !pane0Cmd.isEmpty {
        lines.append("    input text \"\(escape(pane0Cmd))\" to term0")
        lines.append("    send key \"enter\" to term0")
    }

    // Panes 1...N — splits from the previous terminal.
    var previousVar = "term0"
    for (index, pane) in panes.enumerated().dropFirst() {
        let direction = pane.splitDirection
        guard direction == "right" || direction == "down" else { continue }

        let termVar = "term\(index)"
        let cfgVar = "cfg\(index)"
        let absPath = resolvedPath(rootPath: directoryPath, relativeCwd: pane.relativeCwd)

        lines.append("    set \(cfgVar) to new surface configuration")
        lines.append("    set initial working directory of \(cfgVar) to \"\(absPath)\"")
        lines.append("    set \(termVar) to split \(previousVar) direction \(direction) with configuration \(cfgVar)")

        // Defensive cd fallback — `initial working directory` on splits is
        // not 100% confirmed in the preview API. If it works, cd is a no-op.
        lines.append("    input text \"cd \(absPath)\" to \(termVar)")
        lines.append("    send key \"enter\" to \(termVar)")

        // Pane command (optional).
        let cmd = pane.command.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cmd.isEmpty {
            lines.append("    input text \"\(escape(cmd))\" to \(termVar)")
            lines.append("    send key \"enter\" to \(termVar)")
        }

        previousVar = termVar
    }

    // Focus pane 0 so the user starts on the main terminal.
    if panes.count > 1 {
        lines.append("    focus term0")
    }

    lines.append("end tell")
    return lines.joined(separator: "\n")
}

/// Resolves a WorkspacePane's `relativeCwd` against the project root.
/// Returns an absolute POSIX path suitable for `initial working directory`.
func resolvedPath(rootPath: String, relativeCwd: String) -> String {
    let root = rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
    let rel = relativeCwd.trimmingCharacters(in: .whitespacesAndNewlines)

    if rel.isEmpty || rel == "." {
        return root
    }

    // Strip a leading "./" if present for cleaner joined paths.
    var suffix = rel
    if suffix.hasPrefix("./") {
        suffix = String(suffix.dropFirst(2))
    }

    if root.hasSuffix("/") {
        return root + suffix
    }
    return root + "/" + suffix
}

/// Escapes a string for safe inclusion inside an AppleScript double-quoted
/// literal. Only backslashes and double quotes need escaping — everything
/// else (including shell meta-chars like `&&`, `|`, `$`) passes through.
private func escape(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
}

// MARK: - Implementation

@MainActor
struct WorkspaceLauncher: WorkspaceLauncherProtocol {

    func launch(project: Project, panes: [WorkspacePane]) async throws {
        // 1. Validate directoryPath
        let root = project.directoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !root.isEmpty else {
            throw WorkspaceLauncherError.projectHasNoDirectory
        }

        // 2. Detect Ghostty — a pre-check so we can surface a clean error
        //    instead of letting AppleScript fail with a cryptic message.
        guard NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.mitchellh.ghostty"
        ) != nil else {
            throw WorkspaceLauncherError.ghosttyNotInstalled
        }

        // 3. Build the script. `tell application "Ghostty" to activate`
        //    will launch Ghostty if it isn't already running — we don't
        //    need NSWorkspace.openApplication anymore.
        let sorted = panes.sorted { $0.order < $1.order }
        let source = buildLaunchScript(directoryPath: root, panes: sorted)

        // 4. Run the script off the main thread.
        try await runScript(source)
    }

    /// Runs an AppleScript off the main thread.
    ///
    /// CRITICAL: `NSAppleScript` is NOT `Sendable`. It MUST be created AND
    /// executed inside the detached closure — never on `@MainActor` and then
    /// captured. Violating this produces Swift 6 concurrency diagnostics and
    /// real data races.
    private func runScript(_ source: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            var errorDict: NSDictionary?
            guard let script = NSAppleScript(source: source) else {
                throw WorkspaceLauncherError.appleScriptFailed(
                    "Failed to initialize NSAppleScript"
                )
            }
            script.executeAndReturnError(&errorDict)
            if let errorDict {
                let code = errorDict[NSAppleScript.errorNumber] as? Int ?? 0
                if code == -1743 {
                    throw WorkspaceLauncherError.automationPermissionDenied
                }
                let msg = errorDict[NSAppleScript.errorMessage] as? String
                    ?? "Unknown AppleScript error"
                throw WorkspaceLauncherError.appleScriptFailed(msg)
            }
        }.value
    }
}
