//
//  MCPMerger.swift
//  Devtail
//
//  Ordered, deduplicated union of MCP server names discovered across the
//  global ~/.claude.json (top-level + per-project entry) and a
//  project-local .mcp.json. Global entries come first, then any
//  project-only names, preserving each list's own relative order.
//

import Foundation

enum MCPMerger {
    static func merge(global: [String], project: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for name in global + project {
            guard !seen.contains(name) else { continue }
            seen.insert(name)
            result.append(name)
        }
        return result
    }
}
