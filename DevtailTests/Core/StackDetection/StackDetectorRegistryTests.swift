//
//  StackDetectorRegistryTests.swift
//  DevtailTests
//
//  Tests the ranking, tie-breaking, and error-swallowing behavior of
//  StackDetectorRegistry using a configurable mock detector. No real
//  filesystem IO — these are pure state-machine tests.
//

import Testing
import Foundation
@testable import Devtail

@Suite("StackDetectorRegistry")
struct StackDetectorRegistryTests {

    // MARK: - Mock detector

    /// Test double that returns a preconfigured result, throws a
    /// preconfigured error, or returns nil. Records whether it was
    /// called so tests can assert on invocation order.
    struct MockStackDetector: StackDetector {
        let name: String
        let result: DetectedStack?
        let errorToThrow: Error?

        init(
            name: String,
            result: DetectedStack? = nil,
            errorToThrow: Error? = nil
        ) {
            self.name = name
            self.result = result
            self.errorToThrow = errorToThrow
        }

        func detect(folder: URL) async throws -> DetectedStack? {
            if let errorToThrow {
                throw errorToThrow
            }
            return result
        }
    }

    struct TestError: Error {}

    // MARK: - Happy path

    @Test("returns nil when no detectors match")
    func returnsNilWhenNoMatches() async {
        let registry = StackDetectorRegistry(detectors: [
            MockStackDetector(name: "a", result: nil),
            MockStackDetector(name: "b", result: nil)
        ])

        let result = await registry.detectBestMatch(in: URL(fileURLWithPath: "/tmp"))

        #expect(result == nil)
    }

    @Test("returns the single match when only one detector matches")
    func returnsSingleMatch() async {
        let only = DetectedStack(label: "React", suggestedCommand: "npm run dev", confidence: 90)
        let registry = StackDetectorRegistry(detectors: [
            MockStackDetector(name: "empty", result: nil),
            MockStackDetector(name: "react", result: only),
            MockStackDetector(name: "empty2", result: nil)
        ])

        let result = await registry.detectBestMatch(in: URL(fileURLWithPath: "/tmp"))

        #expect(result == only)
    }

    @Test("returns the highest-confidence match when multiple detectors match")
    func returnsHighestConfidence() async {
        let low = DetectedStack(label: "Node", suggestedCommand: nil, confidence: 60)
        let mid = DetectedStack(label: "Python", suggestedCommand: nil, confidence: 75)
        let high = DetectedStack(label: "Django", suggestedCommand: "python manage.py runserver", confidence: 95)

        let registry = StackDetectorRegistry(detectors: [
            MockStackDetector(name: "low", result: low),
            MockStackDetector(name: "high", result: high),
            MockStackDetector(name: "mid", result: mid)
        ])

        let result = await registry.detectBestMatch(in: URL(fileURLWithPath: "/tmp"))

        #expect(result == high)
    }

    // MARK: - Tie-breaking

    @Test("on equal confidence, the first registered detector wins")
    func tieBreakingFavorsFirstRegistered() async {
        let first = DetectedStack(label: "First", suggestedCommand: nil, confidence: 80)
        let second = DetectedStack(label: "Second", suggestedCommand: nil, confidence: 80)

        let registry = StackDetectorRegistry(detectors: [
            MockStackDetector(name: "first", result: first),
            MockStackDetector(name: "second", result: second)
        ])

        let result = await registry.detectBestMatch(in: URL(fileURLWithPath: "/tmp"))

        #expect(result?.label == "First")
    }

    @Test("tie-breaking is deterministic across repeated runs")
    func tieBreakingIsDeterministic() async {
        // Run the same registry many times and verify the same result
        // every single run. If we ever reintroduce concurrency the
        // ordering would flake here.
        let first = DetectedStack(label: "Alpha", suggestedCommand: nil, confidence: 80)
        let second = DetectedStack(label: "Beta", suggestedCommand: nil, confidence: 80)

        let registry = StackDetectorRegistry(detectors: [
            MockStackDetector(name: "alpha", result: first),
            MockStackDetector(name: "beta", result: second)
        ])

        for _ in 0..<20 {
            let result = await registry.detectBestMatch(in: URL(fileURLWithPath: "/tmp"))
            #expect(result?.label == "Alpha")
        }
    }

    // MARK: - Error swallowing

    @Test("a throwing detector is treated as no match and others still run")
    func throwingDetectorIsSwallowed() async {
        let good = DetectedStack(label: "Good", suggestedCommand: nil, confidence: 70)

        let registry = StackDetectorRegistry(detectors: [
            MockStackDetector(name: "broken", errorToThrow: TestError()),
            MockStackDetector(name: "good", result: good)
        ])

        let result = await registry.detectBestMatch(in: URL(fileURLWithPath: "/tmp"))

        #expect(result == good)
    }

    @Test("all detectors throwing results in nil, not a crash")
    func allThrowingReturnsNil() async {
        let registry = StackDetectorRegistry(detectors: [
            MockStackDetector(name: "a", errorToThrow: TestError()),
            MockStackDetector(name: "b", errorToThrow: TestError())
        ])

        let result = await registry.detectBestMatch(in: URL(fileURLWithPath: "/tmp"))

        #expect(result == nil)
    }

    // MARK: - Empty registry

    @Test("empty registry returns nil")
    func emptyRegistryReturnsNil() async {
        let registry = StackDetectorRegistry(detectors: [])

        let result = await registry.detectBestMatch(in: URL(fileURLWithPath: "/tmp"))

        #expect(result == nil)
    }
}
