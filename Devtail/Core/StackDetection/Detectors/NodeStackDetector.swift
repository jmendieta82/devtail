//
//  NodeStackDetector.swift
//  Devtail
//
//  Detects Node-based stacks by inspecting `package.json` in the root
//  of the given folder. Returns a framework-specific result (React,
//  Nest, Next.js) when it recognizes the dependency signature, falling
//  back to generic "Node" when only `package.json` is present.
//
//  Suggested command is derived from the `scripts` object with a
//  priority of `dev` > `start` > `serve`, matching what developers
//  type 95% of the time.
//

import Foundation

struct NodeStackDetector: StackDetector {
    let name = "node"

    /// Maps a dependency name (or prefix) to the label + confidence we
    /// return when that dependency is found. Evaluated top-to-bottom,
    /// first match wins. Register more specific frameworks first.
    private static let frameworkSignatures: [(dependency: String, label: String, confidence: Int)] = [
        // NestJS uses the `@nestjs/*` scope — we match on the core
        // package explicitly rather than the prefix to avoid false
        // positives from unrelated `@nestjs/schematics`-only installs.
        ("@nestjs/core", "Nest",    90),
        ("next",         "Next.js", 90),
        ("react",        "React",   90)
    ]

    /// Script names we look for, in priority order. The first one that
    /// exists wins. `npm run dev` is the modern default; `start` is
    /// the classic fallback for older projects.
    private static let scriptPriority: [String] = ["dev", "start", "serve"]

    func detect(folder: URL) async throws -> DetectedStack? {
        let packageJsonURL = folder.appendingPathComponent("package.json")

        // No package.json → definitely not a Node project.
        guard FileManager.default.fileExists(atPath: packageJsonURL.path) else {
            return nil
        }

        // Read and parse. If parsing fails, treat as "no detection"
        // rather than bubbling the error — the detector subsystem is
        // best-effort and the user can always edit manually.
        guard
            let data = try? Data(contentsOf: packageJsonURL),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            // File exists but can't be parsed — still confident it's
            // a Node project, just no details. Better to say "Node" at
            // lower confidence than say nothing.
            return DetectedStack(label: "Node", suggestedCommand: nil, confidence: 60)
        }

        // Merge dependencies + devDependencies into a single lookup
        // set. We treat both as equal evidence — a dev-only dep like
        // "next" in an internal tool is still enough to call it Next.
        let deps = Self.extractDependencyNames(from: json)
        let scripts = (json["scripts"] as? [String: Any]) ?? [:]

        // Try framework-specific matches first.
        for signature in Self.frameworkSignatures {
            if deps.contains(signature.dependency) {
                return DetectedStack(
                    label: signature.label,
                    suggestedCommand: Self.suggestedCommand(from: scripts),
                    confidence: signature.confidence
                )
            }
        }

        // Generic Node fallback.
        return DetectedStack(
            label: "Node",
            suggestedCommand: Self.suggestedCommand(from: scripts),
            confidence: 60
        )
    }

    /// Collects the names of all declared dependencies and
    /// devDependencies into a single set. Non-dictionary values under
    /// either key are ignored silently — malformed package.json
    /// should not crash the detector.
    private static func extractDependencyNames(from json: [String: Any]) -> Set<String> {
        var result = Set<String>()
        if let deps = json["dependencies"] as? [String: Any] {
            result.formUnion(deps.keys)
        }
        if let devDeps = json["devDependencies"] as? [String: Any] {
            result.formUnion(devDeps.keys)
        }
        return result
    }

    /// Picks the best startup command from the `scripts` object based
    /// on `scriptPriority`. Returns the full `npm run <name>` form
    /// (or `npm start` for the canonical case) as a string ready to
    /// drop into the editor.
    private static func suggestedCommand(from scripts: [String: Any]) -> String? {
        for name in scriptPriority {
            guard scripts[name] is String else { continue }
            if name == "start" {
                return "npm start"
            }
            return "npm run \(name)"
        }
        return nil
    }
}
