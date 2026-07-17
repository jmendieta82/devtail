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
        var input = 0
        var output = 0
        var cache = 0

        for line in jsonlLines {
            guard let usage = usageObject(fromLine: line) else { continue }
            input += intValue(usage["input_tokens"])
            output += intValue(usage["output_tokens"])
            cache += intValue(usage["cache_creation_input_tokens"])
            cache += intValue(usage["cache_read_input_tokens"])
        }

        return TokenUsage(input: input, output: output, cache: cache)
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
