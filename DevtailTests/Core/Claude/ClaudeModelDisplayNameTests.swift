//
//  ClaudeModelDisplayNameTests.swift
//  DevtailTests
//
//  TDD for ClaudeModelDisplayName: maps a raw Claude model id (as recorded
//  in transcript `message.model`) to the short display name shown on the
//  Claude card, falling back to a cleaned raw id for unknown/future models.
//

import Testing
@testable import Devtail

struct ClaudeModelDisplayNameTests {
    @Test func mapsKnownModelIdsToShortNames() {
        #expect(ClaudeModelDisplayName.forId("claude-fable-5-20260101") == "Fable 5")
        #expect(ClaudeModelDisplayName.forId("claude-opus-5-20260101") == "Opus 5")
        #expect(ClaudeModelDisplayName.forId("claude-sonnet-5-20260101") == "Sonnet 5")
        #expect(ClaudeModelDisplayName.forId("claude-haiku-4-5-20260101") == "Haiku 4.5")
    }

    @Test func mapsOpus4PointXIdsToOpusPlusVersionSuffix() {
        #expect(ClaudeModelDisplayName.forId("claude-opus-4-1-20250805") == "Opus 4.1")
        #expect(ClaudeModelDisplayName.forId("claude-opus-4-20250514") == "Opus 4")
    }

    @Test func fallsBackToCleanedRawIdForUnknownModels() {
        #expect(ClaudeModelDisplayName.forId("claude-future-model-9") == "future-model-9")
        #expect(ClaudeModelDisplayName.forId("some-other-id") == "some-other-id")
    }
}
