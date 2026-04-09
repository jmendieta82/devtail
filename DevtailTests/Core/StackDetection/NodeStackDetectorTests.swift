//
//  NodeStackDetectorTests.swift
//  DevtailTests
//
//  Tests NodeStackDetector against real package.json fixtures written
//  to a temporary directory. Each test creates its own isolated folder
//  and cleans up afterwards, so parallel execution is safe.
//

import Testing
import Foundation
@testable import Devtail

@Suite("NodeStackDetector")
struct NodeStackDetectorTests {

    // MARK: - Fixture plumbing

    /// Creates a unique temporary folder, writes `packageJSON` (if
    /// provided) as its `package.json`, and returns the URL. The
    /// caller is responsible for cleanup — each test uses `defer` to
    /// remove it.
    private func makeFolder(packageJSON: String? = nil) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-node-detector-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let packageJSON {
            let target = folder.appendingPathComponent("package.json")
            try packageJSON.data(using: .utf8)!.write(to: target)
        }
        return folder
    }

    private func cleanup(_ folder: URL) {
        try? FileManager.default.removeItem(at: folder)
    }

    // MARK: - No package.json → nil

    @Test("returns nil when package.json is absent")
    func returnsNilWhenNoPackageJson() async throws {
        let folder = try makeFolder(packageJSON: nil)
        defer { cleanup(folder) }

        let detector = NodeStackDetector()
        let result = try await detector.detect(folder: folder)

        #expect(result == nil)
    }

    // MARK: - Framework matches

    @Test("detects React when react is in dependencies")
    func detectsReact() async throws {
        let folder = try makeFolder(packageJSON: """
        {
          "name": "my-app",
          "dependencies": {
            "react": "^18.0.0",
            "react-dom": "^18.0.0"
          },
          "scripts": {
            "dev": "vite"
          }
        }
        """)
        defer { cleanup(folder) }

        let result = try await NodeStackDetector().detect(folder: folder)

        #expect(result?.label == "React")
        #expect(result?.confidence == 90)
        #expect(result?.suggestedCommand == "npm run dev")
    }

    @Test("detects Nest when @nestjs/core is in dependencies")
    func detectsNest() async throws {
        let folder = try makeFolder(packageJSON: """
        {
          "name": "my-api",
          "dependencies": {
            "@nestjs/core": "^10.0.0",
            "@nestjs/common": "^10.0.0"
          },
          "scripts": {
            "start": "nest start",
            "start:dev": "nest start --watch"
          }
        }
        """)
        defer { cleanup(folder) }

        let result = try await NodeStackDetector().detect(folder: folder)

        #expect(result?.label == "Nest")
        #expect(result?.confidence == 90)
        // "start" wins over "start:dev" because we only look at exact names.
        #expect(result?.suggestedCommand == "npm start")
    }

    @Test("detects Next.js when next is in dependencies")
    func detectsNextJS() async throws {
        let folder = try makeFolder(packageJSON: """
        {
          "name": "my-next-app",
          "dependencies": {
            "next": "^14.0.0",
            "react": "^18.0.0"
          },
          "scripts": {
            "dev": "next dev"
          }
        }
        """)
        defer { cleanup(folder) }

        let result = try await NodeStackDetector().detect(folder: folder)

        // Nest-before-Next-before-React ordering in the signatures
        // table means Next wins here over React, which is the right
        // call: a Next app IS a React app, but calling it "Next"
        // is more specific and useful.
        #expect(result?.label == "Next.js")
        #expect(result?.confidence == 90)
    }

    // MARK: - devDependencies

    @Test("matches frameworks declared under devDependencies too")
    func matchesDevDependencies() async throws {
        let folder = try makeFolder(packageJSON: """
        {
          "name": "tooling",
          "devDependencies": {
            "react": "^18.0.0"
          }
        }
        """)
        defer { cleanup(folder) }

        let result = try await NodeStackDetector().detect(folder: folder)

        #expect(result?.label == "React")
    }

    // MARK: - Generic Node fallback

    @Test("falls back to generic Node when no framework is detected")
    func fallsBackToGenericNode() async throws {
        let folder = try makeFolder(packageJSON: """
        {
          "name": "just-node",
          "dependencies": {
            "lodash": "^4.0.0"
          },
          "scripts": {
            "start": "node index.js"
          }
        }
        """)
        defer { cleanup(folder) }

        let result = try await NodeStackDetector().detect(folder: folder)

        #expect(result?.label == "Node")
        #expect(result?.confidence == 60)
        #expect(result?.suggestedCommand == "npm start")
    }

    @Test("returns Node with no command when scripts are missing entirely")
    func noScriptsNoCommand() async throws {
        let folder = try makeFolder(packageJSON: """
        {
          "name": "plain"
        }
        """)
        defer { cleanup(folder) }

        let result = try await NodeStackDetector().detect(folder: folder)

        #expect(result?.label == "Node")
        #expect(result?.suggestedCommand == nil)
    }

    // MARK: - Script priority

    @Test("dev has priority over start and serve")
    func devHasPriority() async throws {
        let folder = try makeFolder(packageJSON: """
        {
          "name": "multi",
          "scripts": {
            "serve": "a",
            "start": "b",
            "dev": "c"
          }
        }
        """)
        defer { cleanup(folder) }

        let result = try await NodeStackDetector().detect(folder: folder)

        #expect(result?.suggestedCommand == "npm run dev")
    }

    @Test("start is used when dev is missing")
    func startUsedWhenNoDev() async throws {
        let folder = try makeFolder(packageJSON: """
        {
          "name": "multi",
          "scripts": {
            "serve": "a",
            "start": "b"
          }
        }
        """)
        defer { cleanup(folder) }

        let result = try await NodeStackDetector().detect(folder: folder)

        #expect(result?.suggestedCommand == "npm start")
    }

    @Test("serve is used when dev and start are missing")
    func serveUsedAsLastResort() async throws {
        let folder = try makeFolder(packageJSON: """
        {
          "name": "multi",
          "scripts": {
            "serve": "a",
            "test": "jest"
          }
        }
        """)
        defer { cleanup(folder) }

        let result = try await NodeStackDetector().detect(folder: folder)

        #expect(result?.suggestedCommand == "npm run serve")
    }

    // MARK: - Malformed package.json

    @Test("corrupted package.json falls back to low-confidence Node")
    func corruptedPackageJsonFallback() async throws {
        let folder = try makeFolder(packageJSON: "this is not valid JSON at all {{{")
        defer { cleanup(folder) }

        let result = try await NodeStackDetector().detect(folder: folder)

        #expect(result?.label == "Node")
        #expect(result?.confidence == 60)
        #expect(result?.suggestedCommand == nil)
    }

    @Test("empty package.json still counts as Node")
    func emptyPackageJsonIsNode() async throws {
        let folder = try makeFolder(packageJSON: "{}")
        defer { cleanup(folder) }

        let result = try await NodeStackDetector().detect(folder: folder)

        #expect(result?.label == "Node")
    }
}
