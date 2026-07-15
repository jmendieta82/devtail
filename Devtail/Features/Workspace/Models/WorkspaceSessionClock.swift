//
//  WorkspaceSessionClock.swift
//  Devtail
//
//  Pure formatter for the workspace session clock card.
//

import Foundation

/// Pure formatter for the workspace session clock card.
enum WorkspaceSessionClock {
    static func elapsedLabel(from start: Date, to now: Date) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(start))) / 60
        if minutes < 1 { return "<1m" }
        if minutes < 60 { return "\(minutes)m" }
        return String(format: "%dh %02dm", minutes / 60, minutes % 60)
    }
}
