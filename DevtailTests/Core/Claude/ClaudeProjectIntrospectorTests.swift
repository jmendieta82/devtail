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

    /// Token usage is now streamed per file (one file's content in memory
    /// at a time, only running int totals carried across files — see
    /// `ClaudeProjectIntrospector.readTokenUsage`). This asserts multiple
    /// transcript files still sum correctly under that streaming path.
    /// Peak-memory-per-file is a design property, not something a unit
    /// test can assert directly.
    @Test func sumsTokenUsageAcrossMultipleTranscriptFiles() {
        let root = makeTempDir()
        let home = makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: home)
        }

        let encoded = ClaudePathEncoder.encode(root.path)
        let line1 = #"{"message":{"usage":{"input_tokens":10,"output_tokens":5,"cache_creation_input_tokens":1,"cache_read_input_tokens":1}}}"#
        let line2 = #"{"message":{"usage":{"input_tokens":20,"output_tokens":8,"cache_creation_input_tokens":0,"cache_read_input_tokens":2}}}"#
        let line3 = #"{"usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}"#
        write(line1, to: home.appendingPathComponent(".claude/projects/\(encoded)/session1.jsonl"))
        write(line2 + "\n" + line3, to: home.appendingPathComponent(".claude/projects/\(encoded)/session2.jsonl"))

        let result = ClaudeProjectIntrospector().introspectSync(projectRoot: root, home: home)

        #expect(result.tokenUsage?.input == 130)
        #expect(result.tokenUsage?.output == 63)
        #expect(result.tokenUsage?.cache == 4)
    }

    @Test func currentModelIsNilWhenNoTranscriptsExist() {
        let root = makeTempDir()
        let home = makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: home)
        }

        let result = ClaudeProjectIntrospector().introspectSync(projectRoot: root, home: home)

        #expect(result.currentModel == nil)
    }

    @Test func currentModelReadsLastModelFromNewestTranscript() {
        let root = makeTempDir()
        let home = makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: home)
        }

        let encoded = ClaudePathEncoder.encode(root.path)
        let projectDir = home.appendingPathComponent(".claude/projects/\(encoded)", isDirectory: true)

        let olderLine = #"{"message":{"model":"claude-opus-4-1-20250805","usage":{"input_tokens":1,"output_tokens":1}}}"#
        write(olderLine, to: projectDir.appendingPathComponent("older.jsonl"))

        let newerLines = [
            #"{"message":{"model":"claude-sonnet-5-20260101","usage":{"input_tokens":1,"output_tokens":1}}}"#,
            #"{"type":"summary","text":"no model here"}"#
        ].joined(separator: "\n")
        write(newerLines, to: projectDir.appendingPathComponent("newer.jsonl"))

        // Ensure deterministic modification-date ordering regardless of
        // filesystem timestamp resolution.
        let fm = FileManager.default
        try! fm.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -60)], ofItemAtPath: projectDir.appendingPathComponent("older.jsonl").path)
        try! fm.setAttributes([.modificationDate: Date()], ofItemAtPath: projectDir.appendingPathComponent("newer.jsonl").path)

        let result = ClaudeProjectIntrospector().introspectSync(projectRoot: root, home: home)

        #expect(result.currentModel == "claude-sonnet-5-20260101")
    }

    @Test func currentModelScansFromLastLineBackwardsWithinNewestTranscript() {
        let root = makeTempDir()
        let home = makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: home)
        }

        let encoded = ClaudePathEncoder.encode(root.path)
        let projectDir = home.appendingPathComponent(".claude/projects/\(encoded)", isDirectory: true)

        let lines = [
            #"{"message":{"model":"claude-opus-4-1-20250805"}}"#,
            #"{"message":{"model":"claude-sonnet-5-20260101"}}"#,
            #"{"type":"summary","text":"trailing line with no model"}"#,
            "not valid json {{{"
        ].joined(separator: "\n")
        write(lines, to: projectDir.appendingPathComponent("session1.jsonl"))

        let result = ClaudeProjectIntrospector().introspectSync(projectRoot: root, home: home)

        #expect(result.currentModel == "claude-sonnet-5-20260101")
    }

    /// Exercises the actual `async` `introspect(projectRoot:home:)` entry
    /// point that production (`WorkspaceSession`) calls, not just the
    /// synchronous `introspectSync` wrapped by every other test here.
    @Test func asyncIntrospectEntryPointReturnsSameResultAsSync() async {
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

        let result = await ClaudeProjectIntrospector().introspect(projectRoot: root, home: home)

        #expect(result.skills.count == 1)
        #expect(result.skills[0].name == "project-skill")
        #expect(result.skills[0].detail == "A project skill")
    }
}
