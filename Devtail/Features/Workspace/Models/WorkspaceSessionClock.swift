//
//  WorkspaceSessionClock.swift
//  Devtail
//
//  Pure formatter for the workspace session clock card.
//

import Foundation

/// Pure formatter for the workspace session clock card. Second-resolution so
/// the card reads as a running stopwatch (MM:SS, or HH:MM:SS past an hour)
/// instead of a value that only changes once a minute.
enum WorkspaceSessionClock {
    static func elapsedLabel(from start: Date, to now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
