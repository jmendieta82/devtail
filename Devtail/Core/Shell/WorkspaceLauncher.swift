//
//  WorkspaceLauncher.swift
//  Devtail
//
//  Opens Ghostty at a project's root directory and drives it via Ghostty's
//  native AppleScript dictionary (available since Ghostty 1.3) to recreate
//  the project's WorkspaceLayout (slots + per-pane cd + command).
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
    case layoutHasUnassignedSlots(missing: [Int])

    static func == (lhs: WorkspaceLauncherError, rhs: WorkspaceLauncherError) -> Bool {
        switch (lhs, rhs) {
        case (.projectHasNoDirectory, .projectHasNoDirectory): return true
        case (.ghosttyNotInstalled, .ghosttyNotInstalled): return true
        case (.automationPermissionDenied, .automationPermissionDenied): return true
        case (.appleScriptFailed(let a), .appleScriptFailed(let b)): return a == b
        case (.layoutHasUnassignedSlots(let a), .layoutHasUnassignedSlots(let b)): return a == b
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
///   Phase A — Topology: for each SplitStep in layout.splitSequence, emit
///   a `split term<sourceSlot> direction <dir>` call that binds the result
///   to `term<newSlot>`. This produces non-sequential splits (Quarters: term2
///   splits from term0, term3 splits from term1) that a sequential chain
///   cannot express.
///
///   Phase B — Content: after ALL splits are done, iterate each slot in
///   order and emit the defensive cd + command for that slot's pane.
///
/// - Parameters:
///   - directoryPath: The project's absolute root path.
///   - layout: The WorkspaceLayout defining slot count and split topology.
///   - panesBySlot: A dictionary mapping slot index → WorkspacePane. Every
///     slot in 0 ..< layout.slotCount MUST have an entry; throws otherwise.
/// - Returns: AppleScript source code ready for NSAppleScript.
/// - Throws: `WorkspaceLauncherError.layoutHasUnassignedSlots` if any slot
///   in 0 ..< layout.slotCount has no pane.
func buildLaunchScript(
    directoryPath: String,
    layout: WorkspaceLayout,
    panesBySlot: [Int: WorkspacePane]
) throws -> String {
    // Pre-validation: every slot must be filled before emitting any script.
    let missing = (0 ..< layout.slotCount).filter { panesBySlot[$0] == nil }
    guard missing.isEmpty else {
        throw WorkspaceLauncherError.layoutHasUnassignedSlots(missing: missing)
    }

    var lines: [String] = []
    lines.append("tell application \"Ghostty\"")
    lines.append("    activate")

    // Slot 0 — the initial window.
    let pane0 = panesBySlot[0]!
    let path0 = resolvedPath(rootPath: directoryPath, relativeCwd: pane0.relativeCwd)

    lines.append("    set cfg0 to new surface configuration")
    lines.append("    set initial working directory of cfg0 to \"\(path0)\"")
    lines.append("    set win to new window with configuration cfg0")
    lines.append("    set term0 to focused terminal of selected tab of win")

    // Phase A — Topology: emit all splits in the layout-defined order.
    for step in layout.splitSequence {
        let srcVar  = "term\(step.sourceSlot)"
        let newVar  = "term\(step.newSlot)"
        let cfgVar  = "cfg\(step.newSlot)"
        let pane    = panesBySlot[step.newSlot]!
        let absPath = resolvedPath(rootPath: directoryPath, relativeCwd: pane.relativeCwd)

        lines.append("    set \(cfgVar) to new surface configuration")
        lines.append("    set initial working directory of \(cfgVar) to \"\(absPath)\"")
        lines.append("    set \(newVar) to split \(srcVar) direction \(step.direction.rawValue) with configuration \(cfgVar)")
    }

    // Phase B — Content: emit cd + command for each slot in order.
    // Slot 0 gets no cd (it was set via initial working directory on the
    // new window). Slots 1+ get a defensive cd in case the split API does
    // not honor `initial working directory`.
    for slot in 0 ..< layout.slotCount {
        let termVar = "term\(slot)"
        let pane    = panesBySlot[slot]!
        let absPath = resolvedPath(rootPath: directoryPath, relativeCwd: pane.relativeCwd)

        if slot != 0 {
            lines.append("    input text \"cd \(absPath)\" to \(termVar)")
            lines.append("    send key \"enter\" to \(termVar)")
        }

        let cmd = pane.command.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cmd.isEmpty {
            lines.append("    input text \"\(escape(cmd))\" to \(termVar)")
            lines.append("    send key \"enter\" to \(termVar)")
        }
    }

    // Focus slot 0 so the user starts on the main terminal.
    if layout.slotCount > 1 {
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

        // 3. Build a slot-indexed dictionary from the pane list, skipping
        //    unassigned panes (layoutSlot == -1). The buildLaunchScript
        //    function will throw if any required slot is missing.
        var panesBySlot: [Int: WorkspacePane] = [:]
        for pane in panes where pane.layoutSlot >= 0 {
            panesBySlot[pane.layoutSlot] = pane
        }

        let source = try buildLaunchScript(
            directoryPath: root,
            layout: project.layout,
            panesBySlot: panesBySlot
        )

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
