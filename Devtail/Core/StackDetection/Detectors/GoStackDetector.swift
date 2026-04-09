//
//  GoStackDetector.swift
//  Devtail
//
//  Detects Go projects via `go.mod`. The presence of `go.mod` is the
//  one and only signal — Go projects without a module file are vanishingly
//  rare in 2026, and Devtail's workspace launcher doesn't need to support
//  pre-modules layouts.
//
//  Framework detection is a substring match against well-known import
//  paths inside the file. We deliberately use substring (not the
//  word-boundary approach used in `PythonStackDetector`) because Go
//  module paths are URL-shaped and unique — `github.com/gin-gonic/gin`
//  cannot collide with any other package name.
//

import Foundation

struct GoStackDetector: StackDetector {
    let name = "go"

    /// Maps a Go module import path prefix to the framework label.
    /// Order matters — first match wins, so put the dominant framework
    /// at the top.
    private static let frameworkSignatures: [(importPath: String, label: String)] = [
        ("github.com/gin-gonic/gin", "Gin"),
        ("github.com/labstack/echo", "Echo"),
        ("github.com/gofiber/fiber", "Fiber")
    ]

    func detect(folder: URL) async throws -> DetectedStack? {
        let goModURL = folder.appendingPathComponent("go.mod")
        guard FileManager.default.fileExists(atPath: goModURL.path) else {
            return nil
        }

        // Read the file. Failure → fall back to generic Go: we already
        // know this is a Go project (go.mod exists), we just couldn't
        // peek inside.
        guard let contents = try? String(contentsOf: goModURL, encoding: .utf8) else {
            return DetectedStack(label: "Go", suggestedCommand: "go run .", confidence: 60)
        }

        for signature in Self.frameworkSignatures {
            if contents.contains(signature.importPath) {
                return DetectedStack(
                    label: signature.label,
                    suggestedCommand: "go run .",
                    confidence: 90
                )
            }
        }

        return DetectedStack(label: "Go", suggestedCommand: "go run .", confidence: 60)
    }
}
