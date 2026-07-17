//
//  StackDetectorRegistry.swift
//  Devtail
//
//  Coordinates the list of available `StackDetector`s. Runs them in
//  registration order and returns the result with the highest
//  confidence. Ties are broken by registration order — whoever was
//  added first wins, which lets us nudge defaults without changing
//  confidence constants.
//
//  Design note: detectors run SEQUENTIALLY rather than concurrently on
//  purpose. Concurrent execution via `withTaskGroup` makes tie-breaking
//  non-deterministic (results come back in completion order, not
//  registration order). Detection IO is tiny — a handful of file reads
//  per detector — so the sequential cost is negligible and we get a
//  guaranteed stable outcome in return.
//

import Foundation
import os.log

struct StackDetectorRegistry: Sendable {
    let detectors: [any StackDetector]

    /// Convenience: the registry used in production with all the
    /// detectors that ship today. Tests build their own instance with
    /// a custom detector list so they don't depend on this.
    ///
    /// Order rationale: detectors are independent (each one looks at
    /// disjoint marker files), so registration order only matters as a
    /// tie-breaker on equal confidence. Listed alphabetically below for
    /// readability — there is no overlap to disambiguate today.
    static let `default` = StackDetectorRegistry(
        detectors: [
            GoStackDetector(),
            NodeStackDetector(),
            PythonStackDetector(),
            SwiftStackDetector()
        ]
    )

    init(detectors: [any StackDetector]) {
        self.detectors = detectors
    }

    /// Runs every detector against `folder` in registration order and
    /// returns the single best match, or `nil` if no detector
    /// recognized the folder. Detectors that throw are treated as "no
    /// match" — we do NOT propagate per-detector failures because the
    /// whole subsystem is best-effort: the user can always edit the
    /// fields manually.
    ///
    /// - Parameter folder: Absolute file URL of the folder to inspect.
    /// - Returns: The highest-confidence detection, or nil.
    func detectBestMatch(in folder: URL) async -> DetectedStack? {
        var best: DetectedStack?

        for detector in detectors {
            let result: DetectedStack?
            do {
                result = try await detector.detect(folder: folder)
            } catch {
                // Swallow errors — a broken detector shouldn't break
                // the whole detection flow. It just means "no match".
                Log.store.debug("Stack detector \(String(describing: type(of: detector)), privacy: .public) skipped for \(folder.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                result = nil
            }

            guard let candidate = result else { continue }

            // STRICTLY greater-than: equal confidence keeps the current
            // winner, so the first detector registered wins ties.
            if best == nil || candidate.confidence > best!.confidence {
                best = candidate
            }
        }

        return best
    }
}
