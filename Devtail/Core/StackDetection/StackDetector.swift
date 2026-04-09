//
//  StackDetector.swift
//  Devtail
//
//  Protocol and result type for the stack auto-detection subsystem used
//  by the Workspace Pane editor. Each concrete detector inspects a folder
//  on disk and returns a `DetectedStack?` — `nil` when no known stack is
//  found, a populated value otherwise. The registry ranks results by
//  confidence and picks the winner.
//
//  Concurrency: detectors MUST be safe to call from a non-main Task —
//  they run under Task.detached so the UI stays responsive while IO is
//  in flight. Do NOT touch @MainActor state from inside a detector.
//

import Foundation

/// The result of a successful stack detection. Specific enough to feed
/// into the editor's `stack` and `command` fields with sensible defaults,
/// while leaving room for the user to override afterwards.
struct DetectedStack: Equatable, Sendable {
    /// Human-readable stack label that will be shown to the user and
    /// stored in `WorkspacePane.stack`. Examples: "React", "Django",
    /// "SwiftUI", "Node", "Python".
    let label: String

    /// Optional suggested command to run when the workspace pane
    /// launches. Examples: "npm run dev", "python manage.py runserver".
    /// `nil` when the stack has no obvious default.
    let suggestedCommand: String?

    /// How confident the detector is about its match, from 0 (no idea)
    /// to 100 (dead certain). The registry uses this value to break ties
    /// when multiple detectors match the same folder. Rough guide:
    ///   - 90+  : specific framework detected with strong signals
    ///            (Django via manage.py, React via dependency in package.json)
    ///   - 60-80: generic language detected with clear signals
    ///            (package.json without a known framework, requirements.txt)
    ///   - 0-50 : very weak signals — usually not worth returning at all
    let confidence: Int
}

/// Contract every stack detector implements. Kept small on purpose —
/// detectors are swapped and added frequently and a simple interface
/// keeps the cost of a new detector to a single file.
protocol StackDetector: Sendable {
    /// A short, stable name for diagnostics and registry ordering debug
    /// output. Not shown to the user.
    var name: String { get }

    /// Inspect the given folder and return a `DetectedStack` if the
    /// detector recognizes the contents, or `nil` otherwise. Must not
    /// throw for "didn't find anything" — reserve throws for real IO
    /// failures (permission denied, corrupted file, etc.).
    ///
    /// - Parameter folder: Absolute file URL of the folder to inspect.
    ///                     The caller has already verified it exists and
    ///                     is a directory.
    /// - Returns: A detected stack, or nil when no match.
    func detect(folder: URL) async throws -> DetectedStack?
}
