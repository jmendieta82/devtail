//
//  TokenAggregatorTests.swift
//  DevtailTests
//
//  TDD for TokenAggregator: sums input/output/cache token usage across raw
//  JSONL lines from Claude Code transcript files. Each line may carry
//  `message.usage` or a top-level `usage`; lines without either (or that
//  fail to parse as JSON) are skipped rather than treated as an error —
//  transcripts are best-effort data.
//

import Testing
@testable import Devtail

struct TokenAggregatorTests {
    @Test func sumsUsageFromMessageUsageField() {
        let lines = [
            #"{"message":{"usage":{"input_tokens":10,"output_tokens":5,"cache_creation_input_tokens":2,"cache_read_input_tokens":3}}}"#,
            #"{"message":{"usage":{"input_tokens":20,"output_tokens":8,"cache_creation_input_tokens":0,"cache_read_input_tokens":1}}}"#
        ]
        let usage = TokenAggregator.sum(jsonlLines: lines)
        #expect(usage.input == 30)
        #expect(usage.output == 13)
        #expect(usage.cache == 6)
    }

    @Test func sumsUsageFromTopLevelUsageField() {
        let lines = [
            #"{"usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}"#
        ]
        let usage = TokenAggregator.sum(jsonlLines: lines)
        #expect(usage.input == 100)
        #expect(usage.output == 50)
        #expect(usage.cache == 0)
    }

    @Test func skipsLinesWithoutUsage() {
        let lines = [
            #"{"type":"summary","text":"no usage here"}"#,
            #"{"message":{"usage":{"input_tokens":5,"output_tokens":2,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}"#
        ]
        let usage = TokenAggregator.sum(jsonlLines: lines)
        #expect(usage.input == 5)
        #expect(usage.output == 2)
    }

    @Test func skipsInvalidJSONLines() {
        let lines = [
            "not valid json {{{",
            #"{"message":{"usage":{"input_tokens":7,"output_tokens":3,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}"#
        ]
        let usage = TokenAggregator.sum(jsonlLines: lines)
        #expect(usage.input == 7)
        #expect(usage.output == 3)
    }

    @Test func emptyInputReturnsZeroedUsage() {
        let usage = TokenAggregator.sum(jsonlLines: [])
        #expect(usage.input == 0)
        #expect(usage.output == 0)
        #expect(usage.cache == 0)
        #expect(usage.total == 0)
    }
}
