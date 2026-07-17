//
//  TokenCountFormatter.swift
//  Devtail
//
//  Compact display for large token counts in the Claude card:
//  1_234_567 -> "1.2M", 340_000 -> "340k", counts under 1000 as-is.
//

import Foundation

enum TokenCountFormatter {
    static func format(_ count: Int) -> String {
        switch count {
        case ..<1_000:
            return "\(count)"
        case ..<1_000_000:
            return "\(count / 1_000)k"
        default:
            let millions = Double(count) / 1_000_000
            return String(format: "%.1fM", millions)
        }
    }
}
