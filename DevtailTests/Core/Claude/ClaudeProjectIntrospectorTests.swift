//
//  ClaudeProjectIntrospectorTests.swift
//  DevtailTests
//
//  End-to-end tests for ClaudeProjectIntrospector against real temp
//  directories standing in for a project root and `home` — no mocks needed,
//  since the introspector only reads plain files/directories via
//  FileManager. Each test builds the minimal on-disk shape described in the
//  design doc, then asserts on the returned ClaudeIntrospection.
//

import Foundation
import Testing
@testable import Devtail

struct ClaudeProjectIntrospectorTests {
    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeIntrospectorTests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ content: String, to url: URL) {
        try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! content.write(to: url, atomically: true, encoding: .utf8)
    }

    @Test func returnsEmptyIntrospectionWhenNoClaudeConfigExists() {
        let root = makeTempDir()
        let home = makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: home)
        }

        let result = ClaudeProjectIntrospector().introspectSync(projectRoot: root, home: home)

        #expect(result.skills.isEmpty)
        #expect(result.agents.isEmpty)
        #expect(result.commands.isEmpty)
        #expect(result.mcpServers.isEmpty)
        #expect(result.tokenUsage == nil)
    }

    @Test func discoversProjectAndGlobalSkills() {
        let root = makeTempDir()
        let home = makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: home)
        }

        write(
            "---\nname: project-skill\ndescription: A project skill\n---\nBody",
            to: root.appendingPathComponent(".claude/skills/project-skill/SKILL.md")
        )
        write(
            "---\nname: global-skill\ndescription: A global skill\n---\nBody",
            to: home.appendingPathComponent(".claude/skills/global-skill/SKILL.md")
        )

        let result = ClaudeProjectIntrospector().introspectSync(projectRoot: root, home: home)

        #expect(result.skills.count == 2)
        #expect(result.skills.contains { $0.name == "project-skill" && $0.scope == .project })
        #expect(result.skills.contains { $0.name == "global-skill" && $0.scope == .global })
    }

    @Test func discoversAgentsWithFilenameFallback() {
        let root = makeTempDir()
        let home = makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: home)
        }

        write(
            "---\nname: named-agent\n---\nBody",
            to: root.appendingPathComponent(".claude/agents/named-agent.md")
        )
        write(
            "No frontmatter at all",
            to: root.appendingPathComponent(".claude/agents/fallback-agent.md")
        )

        let result = ClaudeProjectIntrospector().introspectSync(projectRoot: root, home: home)

        #expect(result.agents.count == 2)
        #expect(result.agents.contains { $0.name == "named-agent" })
        #expect(result.agents.contains { $0.name == "fallback-agent" })
    }

    @Test func discoversCommandsNamedByFilename() {
        let root = makeTempDir()
        let home = makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: home)
        }

        write("Do the thing", to: root.appendingPathComponent(".claude/commands/sdd-apply.md"))

        let result = ClaudeProjectIntrospector().introspectSync(projectRoot: root, home: home)

        #expect(result.commands.count == 1)
        #expect(result.commands[0].name == "sdd-apply")
        #expect(result.commands[0].scope == .project)
    }

    @Test func mergesMCPServersFromGlobalConfigAndProjectFile() {
        let root = makeTempDir()
        let home = makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: home)
        }

        let projectPath = root.path
        let globalConfig = """
        {
          "mcpServers": { "global-one": {} },
          "projects": {
            "\(projectPath.replacingOccurrences(of: "\\", with: "\\\\"))": {
              "mcpServers": { "per-project-one": {} }
            }
          }
        }
        """
        write(globalConfig, to: home.appendingPathComponent(".claude.json"))
        write(
            #"{ "mcpServers": { "local-one": {}, "global-one": {} } }"#,
            to: root.appendingPathComponent(".mcp.json")
        )

        let result = ClaudeProjectIntrospector().introspectSync(projectRoot: root, home: home)

        #expect(Set(result.mcpServers) == Set(["global-one", "per-project-one", "local-one"]))
    }

    @Test func aggregatesTokenUsageFromTranscripts() {
        let root = makeTempDir()
        let home = makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: home)
        }

        let encoded = ClaudePathEncoder.encode(root.path)
        let line = #"{"message":{"usage":{"input_tokens":10,"output_tokens":5,"cache_creation_input_tokens":1,"cache_read_input_tokens":1}}}"#
        write(
            line,
            to: home.appendingPathComponent(".claude/projects/\(encoded)/session1.jsonl")
        )

        let result = ClaudeProjectIntrospector().introspectSync(projectRoot: root, home: home)

        #expect(result.tokenUsage?.input == 10)
        #expect(result.tokenUsage?.output == 5)
        #expect(result.tokenUsage?.cache == 2)
    }
}
