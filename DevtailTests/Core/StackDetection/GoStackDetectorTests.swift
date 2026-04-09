//
//  GoStackDetectorTests.swift
//  DevtailTests
//
//  Tests GoStackDetector against go.mod fixtures. Same temp-folder
//  isolation pattern as the other detector tests.
//

import Testing
import Foundation
@testable import Devtail

@Suite("GoStackDetector")
struct GoStackDetectorTests {

    // MARK: - Fixture plumbing

    private func makeFolder(goMod: String? = nil) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-go-detector-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let goMod {
            let target = folder.appendingPathComponent("go.mod")
            try goMod.data(using: .utf8)!.write(to: target)
        }
        return folder
    }

    private func cleanup(_ folder: URL) {
        try? FileManager.default.removeItem(at: folder)
    }

    // MARK: - No go.mod → nil

    @Test("returns nil when go.mod is absent")
    func returnsNilWhenNoGoMod() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }

        let result = try await GoStackDetector().detect(folder: folder)

        #expect(result == nil)
    }

    // MARK: - Generic Go

    @Test("falls back to generic Go when go.mod has no known framework")
    func genericGoFallback() async throws {
        let folder = try makeFolder(goMod: """
        module example.com/myapp

        go 1.22

        require (
            github.com/google/uuid v1.6.0
        )
        """)
        defer { cleanup(folder) }

        let result = try await GoStackDetector().detect(folder: folder)

        #expect(result?.label == "Go")
        #expect(result?.confidence == 60)
        #expect(result?.suggestedCommand == "go run .")
    }

    @Test("empty-ish go.mod still counts as Go")
    func minimalGoMod() async throws {
        let folder = try makeFolder(goMod: """
        module example.com/lib

        go 1.22
        """)
        defer { cleanup(folder) }

        let result = try await GoStackDetector().detect(folder: folder)

        #expect(result?.label == "Go")
    }

    // MARK: - Frameworks

    @Test("detects Gin via require block")
    func detectsGin() async throws {
        let folder = try makeFolder(goMod: """
        module example.com/api

        go 1.22

        require (
            github.com/gin-gonic/gin v1.9.1
            github.com/google/uuid v1.6.0
        )
        """)
        defer { cleanup(folder) }

        let result = try await GoStackDetector().detect(folder: folder)

        #expect(result?.label == "Gin")
        #expect(result?.confidence == 90)
        #expect(result?.suggestedCommand == "go run .")
    }

    @Test("detects Echo via require block")
    func detectsEcho() async throws {
        let folder = try makeFolder(goMod: """
        module example.com/api

        go 1.22

        require github.com/labstack/echo/v4 v4.11.4
        """)
        defer { cleanup(folder) }

        let result = try await GoStackDetector().detect(folder: folder)

        #expect(result?.label == "Echo")
        #expect(result?.confidence == 90)
    }

    @Test("detects Fiber via require block")
    func detectsFiber() async throws {
        let folder = try makeFolder(goMod: """
        module example.com/api

        go 1.22

        require (
            github.com/gofiber/fiber/v2 v2.52.0
        )
        """)
        defer { cleanup(folder) }

        let result = try await GoStackDetector().detect(folder: folder)

        #expect(result?.label == "Fiber")
        #expect(result?.confidence == 90)
    }

    // MARK: - Priority

    @Test("first declared framework in the signatures table wins ties")
    func firstFrameworkWinsTie() async throws {
        // The signatures table is ordered Gin → Echo → Fiber, so a
        // pathological project that imports all three should pick Gin.
        // This locks in the registration order as part of the contract.
        let folder = try makeFolder(goMod: """
        module example.com/api

        go 1.22

        require (
            github.com/gin-gonic/gin v1.9.1
            github.com/labstack/echo/v4 v4.11.4
            github.com/gofiber/fiber/v2 v2.52.0
        )
        """)
        defer { cleanup(folder) }

        let result = try await GoStackDetector().detect(folder: folder)

        #expect(result?.label == "Gin")
    }

    // MARK: - Robustness

    @Test("malformed go.mod still falls back to Go")
    func malformedGoMod() async throws {
        let folder = try makeFolder(goMod: "this is garbage \\not valid (((")
        defer { cleanup(folder) }

        let result = try await GoStackDetector().detect(folder: folder)

        #expect(result?.label == "Go")
        #expect(result?.confidence == 60)
    }
}
