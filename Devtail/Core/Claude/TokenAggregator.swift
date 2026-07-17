//
//  TokenAggregator.swift
//  Devtail
//
//  Sums input/output/cache token usage across raw JSONL lines from Claude
//  Code transcript files (~/.claude/projects/<encoded-root>/*.jsonl). Each
//  line may carry `message.usage` or a top-level `usage`; lines without
//  either, or that fail to parse as JSON, are skipped — transcripts are
//  best-effort data, never a hard failure.
//

import Foundation

/// Accumulated token usage. `cache` combines both cache-creation and
/// cache-read tokens — the card shows one aggregate figure, not the
/// underlying breakdown (see design doc).
struct TokenUsage: Equatable, Sendable {
    let input: Int
    let output: Int
    let cache: Int

    var total: Int { input + output + cache }
}

enum TokenAggregator {
    static func sum(jsonlLines: [String]) -> TokenUsage {
        var usage = TokenUsage(input: 0, output: 0, cache: 0)
        accumulate(jsonlLines: jsonlLines, into: &usage)
        return usage
    }

    /// Streaming-friendly variant: adds `jsonlLines`' totals into `usage` in
    /// place, rather than allocating a fresh `TokenUsage`. Lets callers sum
    /// one file's lines at a time — accumulating only the running int
    /// totals across files — instead of holding every file's lines in one
    /// combined `[String]` array before summing (see
    /// `ClaudeProjectIntrospector.readTokenUsage`, which sums per file and
    /// adds each file's partial `TokenUsage` into a running total to bound
    /// peak memory to one file's contents at a time).
    static func accumulate(jsonlLines: [String], into usage: inout TokenUsage) {
        var input = usage.input
        var output = usage.output
        var cache = usage.cache

        for line in jsonlLines {
            guard let parsed = usageObject(fromLine: line) else { continue }
            input += intValue(parsed["input_tokens"])
            output += intValue(parsed["output_tokens"])
            cache += intValue(parsed["cache_creation_input_tokens"])
            cache += intValue(parsed["cache_read_input_tokens"])
        }

        usage = TokenUsage(input: input, output: output, cache: cache)
    }

    private static func usageObject(fromLine line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let message = json["message"] as? [String: Any], let usage = message["usage"] as? [String: Any] {
            return usage
        }
        if let usage = json["usage"] as? [String: Any] {
            return usage
        }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int {
        (value as? Int) ?? 0
    }
}
