//
//  MCPMergerTests.swift
//  DevtailTests
//
//  TDD for MCPMerger: ordered, deduplicated union of MCP server names
//  discovered across the global ~/.claude.json (top-level + per-project
//  entry) and a project-local .mcp.json.
//

import Testing
@testable import Devtail

struct MCPMergerTests {
    @Test func deduplicatesNamesPresentInBothLists() {
        let merged = MCPMerger.merge(global: ["alpha", "beta"], project: ["beta", "gamma"])
        #expect(merged == ["alpha", "beta", "gamma"])
    }

    @Test func preservesGlobalThenProjectOrder() {
        let merged = MCPMerger.merge(global: ["one", "two"], project: ["three"])
        #expect(merged == ["one", "two", "three"])
    }

    @Test func handlesEmptyProjectList() {
        let merged = MCPMerger.merge(global: ["alpha"], project: [])
        #expect(merged == ["alpha"])
    }

    @Test func handlesEmptyGlobalList() {
        let merged = MCPMerger.merge(global: [], project: ["alpha"])
        #expect(merged == ["alpha"])
    }

    @Test func handlesBothEmpty() {
        let merged = MCPMerger.merge(global: [], project: [])
        #expect(merged.isEmpty)
    }
}
