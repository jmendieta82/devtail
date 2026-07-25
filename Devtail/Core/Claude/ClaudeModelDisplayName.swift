//
//  ClaudeModelDisplayName.swift
//  Devtail
//
//  Maps a raw Claude model id (as recorded in transcript `message.model`,
//  e.g. "claude-sonnet-5-20260101") to the short display name shown on the
//  Claude card. Falls back to a cleaned raw id (the "claude-" prefix
//  stripped) for unknown/future models rather than failing — see
//  docs/superpowers/specs/2026-07-24-claude-card-model-design.md.
//

import Foundation

enum ClaudeModelDisplayName {
    static func forId(_ id: String) -> String {
        if id.hasPrefix("claude-fable-5") {
            return "Fable 5"
        }
        if id.hasPrefix("claude-opus-5") {
            return "Opus 5"
        }
        if id.hasPrefix("claude-sonnet-5") {
            return "Sonnet 5"
        }
        if id.hasPrefix("claude-haiku-4-5") {
            return "Haiku 4.5"
        }
        if id.hasPrefix("claude-opus-4") {
            return opus4DisplayName(for: id)
        }
        if id.hasPrefix("claude-") {
            return String(id.dropFirst("claude-".count))
        }
        return id
    }

    /// `claude-opus-4-1-20250805` -> "Opus 4.1"; `claude-opus-4-20250514`
    /// (no minor version segment before the date) -> "Opus 4". The minor
    /// version segment is distinguished from the trailing release-date
    /// segment (e.g. "20250514") by length: dates are always 8 digits,
    /// minor versions are 1-2.
    private static func opus4DisplayName(for id: String) -> String {
        let remainder = id.dropFirst("claude-opus-4".count)
        let segments = remainder.split(separator: "-")
        guard let first = segments.first, first.count <= 2, Int(first) != nil else {
            return "Opus 4"
        }
        return "Opus 4.\(first)"
    }
}
