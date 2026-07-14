//
//  RelativeDateFormatter.swift
//  Devtail
//
//  Produces compact, human-friendly relative-date labels for the "Last seen"
//  chip in the sidebar. The intervals are designed for developer context —
//  anything under a minute is noise, weeks matter, and nothing is scarier
//  than "Long ago" for a project you forgot about.
//

import Foundation

enum RelativeDateFormatter {

    /// Returns a compact label for how long ago `date` was, relative to now.
    /// Returns `nil` when `date` is nil (never launched).
    ///
    /// Cutoffs:
    ///   <= 5 min  → "Just now"
    ///   < 1 h     → "Recently"
    ///   1–23 h    → "Xh ago"
    ///   24–47 h   → "Yesterday"
    ///   2–6 d     → "X days ago"
    ///   7–13 d    → "Last week"
    ///   14–29 d   → "X weeks ago"
    ///   30–59 d   → "Last month"
    ///   60 d+     → "Long ago"
    static func label(for date: Date?) -> String? {
        guard let date else { return nil }

        let seconds = Date.now.timeIntervalSince(date)
        let hours   = seconds / 3600
        let days    = seconds / 86400

        switch seconds {
        case ..<300:
            return "Just now"
        case 300..<3600:
            return "Recently"
        case 3600..<86400:
            let h = Int(hours)
            return "\(h)h ago"
        case 86400..<(86400 * 2):
            return "Yesterday"
        case (86400 * 2)..<(86400 * 7):
            let d = Int(days)
            return "\(d) days ago"
        case (86400 * 7)..<(86400 * 14):
            return "Last week"
        case (86400 * 14)..<(86400 * 30):
            let w = Int(days / 7)
            return "\(w) weeks ago"
        case (86400 * 30)..<(86400 * 60):
            return "Last month"
        default:
            return "Long ago"
        }
    }
}
