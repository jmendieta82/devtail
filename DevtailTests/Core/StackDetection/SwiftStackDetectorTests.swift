//
//  SwiftStackDetectorTests.swift
//  DevtailTests
//
//  Tests SwiftStackDetector using temp folders. Mirrors the fixture
//  approach from the Node and Python detector test suites.
//

import Testing
import Foundation
@testable import Devtail

@Suite("SwiftStackDetector")
struct SwiftStackDetectorTests {

    // MARK: - Fixture plumbing

    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-swift-detector-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func touch(_ name: String, in folder: URL) throws {
        let target = folder.appendingPathComponent(name)
        try Data().write(to: target)
    }

    /// Creates a directory entry (Xcode bundles like `.xcodeproj` and
    /// `.xcworkspace` are folders on disk, not regular files).
    private func touchDirectory(_ name: String, in folder: URL) throws {
        let target = folder.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    }

    private func cleanup(_ folder: URL) {
        try? FileManager.default.removeItem(at: folder)
    }

    // MARK: - No signals

    @Test("returns nil when there are no Swift markers")
    func returnsNilWithNoMarkers() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }

        let result = try await SwiftStackDetector().detect(folder: folder)

        #expect(result == nil)
    }

    // MARK: - SwiftPM

    @Test("detects SwiftPM via Package.swift")
    func detectsSwiftPM() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try touch("Package.swift", in: folder)

        let result = try await SwiftStackDetector().detect(folder: folder)

        #expect(result?.label == "SwiftPM")
        #expect(result?.confidence == 90)
        #expect(result?.suggestedCommand == "swift run")
    }

    // MARK: - Xcode project

    @Test("detects Xcode project via .xcodeproj bundle")
    func detectsXcodeProject() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try touchDirectory("MyApp.xcodeproj", in: folder)

        let result = try await SwiftStackDetector().detect(folder: folder)

        #expect(result?.label == "Xcode")
        #expect(result?.confidence == 90)
        #expect(result?.suggestedCommand == "open MyApp.xcodeproj")
    }

    // MARK: - Xcode workspace

    @Test("detects Xcode workspace via .xcworkspace bundle")
    func detectsXcodeWorkspace() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try touchDirectory("MyApp.xcworkspace", in: folder)

        let result = try await SwiftStackDetector().detect(folder: folder)

        #expect(result?.label == "Xcode")
        #expect(result?.suggestedCommand == "open MyApp.xcworkspace")
    }

    // MARK: - Priority

    @Test("xcworkspace wins over xcodeproj when both exist")
    func workspaceBeatsProject() async throws {
        // Cocoapods/SPM-as-dep projects ship both — the workspace is
        // the canonical entry point because it includes the deps.
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try touchDirectory("MyApp.xcodeproj", in: folder)
        try touchDirectory("MyApp.xcworkspace", in: folder)

        let result = try await SwiftStackDetector().detect(folder: folder)

        #expect(result?.suggestedCommand == "open MyApp.xcworkspace")
    }

    @Test("xcodeproj wins over Package.swift when both exist")
    func xcodeprojBeatsPackageSwift() async throws {
        // An app that uses Package.swift only as a manifest still wants
        // the Xcode IDE to be the entry point.
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try touch("Package.swift", in: folder)
        try touchDirectory("MyApp.xcodeproj", in: folder)

        let result = try await SwiftStackDetector().detect(folder: folder)

        #expect(result?.label == "Xcode")
        #expect(result?.suggestedCommand == "open MyApp.xcodeproj")
    }

    // MARK: - Multiple bundles of the same kind

    @Test("when multiple xcodeproj exist, the first alphabetically wins")
    func multipleXcodeprojDeterministic() async throws {
        // Edge case: monorepo-style folder with several apps. We need a
        // deterministic pick — alphabetical order is the simplest stable
        // rule and matches what Finder shows.
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try touchDirectory("ZApp.xcodeproj", in: folder)
        try touchDirectory("AApp.xcodeproj", in: folder)

        let result = try await SwiftStackDetector().detect(folder: folder)

        #expect(result?.suggestedCommand == "open AApp.xcodeproj")
    }
}
