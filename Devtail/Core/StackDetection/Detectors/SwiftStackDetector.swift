//
//  SwiftStackDetector.swift
//  Devtail
//
//  Detects Swift / Apple-platform projects by scanning the folder for
//  the canonical manifest types, in priority order:
//
//  1. `*.xcworkspace` (highest priority — workspaces wrap projects and
//     are the correct entry point when both exist).
//  2. `*.xcodeproj` (second — opens directly in Xcode).
//  3. `Package.swift` (lowest — bare SwiftPM, run via `swift run`).
//
//  Multiple bundles of the same kind are picked alphabetically so the
//  result is deterministic across runs. The suggested command always
//  points at the specific bundle name we matched, so the user gets a
//  copy-pasteable command rather than a generic placeholder.
//

import Foundation

struct SwiftStackDetector: StackDetector {
    let name = "swift"

    func detect(folder: URL) async throws -> DetectedStack? {
        let fm = FileManager.default

        // List the folder once. We tolerate IO failures here as "no
        // detection" — the registry will fall through to other detectors.
        let entries: [String]
        do {
            entries = try fm.contentsOfDirectory(atPath: folder.path)
        } catch {
            return nil
        }

        // Tier 1 — workspace bundles. Sorted alphabetically so the first
        // hit is deterministic in folders with several workspaces.
        let workspaces = entries.filter { $0.hasSuffix(".xcworkspace") }.sorted()
        if let workspace = workspaces.first {
            return DetectedStack(
                label: "Xcode",
                suggestedCommand: "open \(workspace)",
                confidence: 90
            )
        }

        // Tier 2 — bare project bundles.
        let projects = entries.filter { $0.hasSuffix(".xcodeproj") }.sorted()
        if let project = projects.first {
            return DetectedStack(
                label: "Xcode",
                suggestedCommand: "open \(project)",
                confidence: 90
            )
        }

        // Tier 3 — SwiftPM manifest at the root.
        if entries.contains("Package.swift") {
            return DetectedStack(
                label: "SwiftPM",
                suggestedCommand: "swift run",
                confidence: 90
            )
        }

        return nil
    }
}
