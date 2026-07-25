//
//  ClaudeProjectIntrospector.swift
//  Devtail
//
//  Reads a project's Claude Code configuration off disk: skills, agents,
//  slash commands, MCP servers, and historical token usage. Best-effort by
//  design — every section is independently optional, a missing/unreadable
//  file or directory simply yields an empty result for that section rather
//  than throwing. `home` is injected (not resolved via
//  FileManager.default.homeDirectoryForCurrentUser internally) so tests can
//  point it at a temp directory instead of the real `~`.
//
//  See docs/superpowers/specs/2026-07-16-claude-introspection-design.md for
//  the exact verified on-disk formats this reads.
//

import Foundation
import os.log

/// Where a discovered item (skill/agent/command) or MCP server came from:
/// the project's own `.claude/` directory, or the user's global `~/.claude/`.
enum ClaudeScope: Sendable {
    case project
    case global
}

/// One discovered skill, agent, or command.
struct ClaudeItem: Equatable, Sendable {
    let name: String
    let detail: String?
    let scope: ClaudeScope

    static func == (lhs: ClaudeItem, rhs: ClaudeItem) -> Bool {
        lhs.name == rhs.name && lhs.detail == rhs.detail && lhs.scope == rhs.scope
    }
}

extension ClaudeScope: Equatable {}

/// Full snapshot of a project's Claude Code configuration, as read by
/// `ClaudeProjectIntrospector.introspect(projectRoot:home:)`.
struct ClaudeIntrospection: Sendable {
    let skills: [ClaudeItem]
    let agents: [ClaudeItem]
    let commands: [ClaudeItem]
    let mcpServers: [String]
    let tokenUsage: TokenUsage?
    /// Raw model id actually used in the most recent session, read from the
    /// newest transcript — not the settings-configured model, which goes
    /// stale after a mid-session `/model` switch. Nil when there are no
    /// transcripts yet.
    let currentModel: String?

    static let empty = ClaudeIntrospection(skills: [], agents: [], commands: [], mcpServers: [], tokenUsage: nil, currentModel: nil)

    /// True when there is nothing at all to show: no items in any category,
    /// no MCP servers, and no token usage. Drives the "No Claude config"
    /// fallback in the dashboard card.
    var isEmpty: Bool {
        skills.isEmpty && agents.isEmpty && commands.isEmpty && mcpServers.isEmpty && tokenUsage == nil
    }
}

/// Injection seam for `WorkspaceSession`'s claude-info loading: the real
/// implementation reads the filesystem (not headless-mockable in the usual
/// sense, but slow/best-effort enough to warrant a seam for cancellation
/// testing the same way `GitStatusReading` does).
protocol ClaudeIntrospecting: Sendable {
    func introspect(projectRoot: URL, home: URL) async -> ClaudeIntrospection
}

struct ClaudeProjectIntrospector: ClaudeIntrospecting, Sendable {
    init() {}

    /// Synchronous, pure-disk-reading entry point used directly by tests
    /// (temp directories, no need to hop actors) and by the `async`
    /// `ClaudeIntrospecting` conformance below, which just wraps this for
    /// the real off-main-actor call site in `WorkspaceSession`. Named
    /// distinctly from the protocol's `introspect(projectRoot:home:)` async
    /// requirement to avoid same-name overload ambiguity at the call site
    /// in the `async` wrapper below.
    func introspectSync(projectRoot: URL, home: URL, isCancelled: @Sendable () -> Bool = { false }) -> ClaudeIntrospection {
        let skills = discoverItems(
            projectDir: projectRoot.appendingPathComponent(".claude/skills", isDirectory: true),
            globalDir: home.appendingPathComponent(".claude/skills", isDirectory: true),
            fileName: "SKILL.md",
            isSkill: true
        )
        let agents = discoverItems(
            projectDir: projectRoot.appendingPathComponent(".claude/agents", isDirectory: true),
            globalDir: home.appendingPathComponent(".claude/agents", isDirectory: true),
            fileName: nil,
            isSkill: false
        )
        let commands = discoverItems(
            projectDir: projectRoot.appendingPathComponent(".claude/commands", isDirectory: true),
            globalDir: home.appendingPathComponent(".claude/commands", isDirectory: true),
            fileName: nil,
            isSkill: false
        )
        let mcpServers = discoverMCPServers(projectRoot: projectRoot, home: home)
        let tokenUsage = readTokenUsage(projectRoot: projectRoot, home: home, isCancelled: isCancelled)
        let currentModel = readCurrentModel(projectRoot: projectRoot, home: home, isCancelled: isCancelled)

        return ClaudeIntrospection(
            skills: skills,
            agents: agents,
            commands: commands,
            mcpServers: mcpServers,
            tokenUsage: tokenUsage,
            currentModel: currentModel
        )
    }

    func introspect(projectRoot: URL, home: URL) async -> ClaudeIntrospection {
        introspectSync(projectRoot: projectRoot, home: home, isCancelled: { Task.isCancelled })
    }

    // MARK: - Skills / Agents / Commands

    /// Discovers items in both `projectDir` and `globalDir`.
    ///
    /// - When `fileName` is provided (skills): each item lives in its own
    ///   subdirectory as `<subdir>/<fileName>` (e.g. `SKILL.md`), and the
    ///   item's name comes from frontmatter `name`, falling back to the
    ///   subdirectory name.
    /// - When `fileName` is nil (agents/commands): each item is a single
    ///   `.md` file directly inside the directory, and the item's name
    ///   comes from frontmatter `name`, falling back to the filename
    ///   (without extension).
    private func discoverItems(projectDir: URL, globalDir: URL, fileName: String?, isSkill: Bool) -> [ClaudeItem] {
        discoverItems(in: projectDir, scope: .project, fileName: fileName)
            + discoverItems(in: globalDir, scope: .global, fileName: fileName)
    }

    private func discoverItems(in directory: URL, scope: ClaudeScope, fileName: String?) -> [ClaudeItem] {
        let fm = FileManager.default
        let entries: [URL]
        do {
            entries = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // Missing directory is the normal "no items" case — only an
            // existing-but-unreadable one is worth a log line.
            return []
        } catch {
            Log.claude.error("Claude introspection listing failed at \(directory.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }

        var items: [ClaudeItem] = []
        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            if let fileName {
                // Skills: <entry>/<fileName>
                var isDirectory: ObjCBool = false
                guard fm.fileExists(atPath: entry.path, isDirectory: &isDirectory), isDirectory.boolValue else { continue }
                let markdownURL = entry.appendingPathComponent(fileName)
                guard let content = try? String(contentsOf: markdownURL, encoding: .utf8) else { continue }
                let frontmatter = FrontmatterParser.parse(content)
                let name = frontmatter["name"] ?? entry.lastPathComponent
                items.append(ClaudeItem(name: name, detail: frontmatter["description"], scope: scope))
            } else {
                // Agents/commands: flat *.md files
                guard entry.pathExtension == "md" else { continue }
                guard let content = try? String(contentsOf: entry, encoding: .utf8) else { continue }
                let frontmatter = FrontmatterParser.parse(content)
                let name = frontmatter["name"] ?? entry.deletingPathExtension().lastPathComponent
                items.append(ClaudeItem(name: name, detail: frontmatter["description"], scope: scope))
            }
        }
        return items
    }

    // MARK: - MCP servers

    private func discoverMCPServers(projectRoot: URL, home: URL) -> [String] {
        let globalNames = readGlobalMCPServerNames(projectRoot: projectRoot, home: home)
        let projectNames = readProjectMCPServerNames(projectRoot: projectRoot)
        return MCPMerger.merge(global: globalNames, project: projectNames)
    }

    /// Reads `~/.claude.json`'s top-level `mcpServers` plus
    /// `projects["<projectRoot>"].mcpServers`, merged (order: top-level
    /// first, then per-project).
    private func readGlobalMCPServerNames(projectRoot: URL, home: URL) -> [String] {
        let configURL = home.appendingPathComponent(".claude.json")
        let data: Data
        do {
            data = try Data(contentsOf: configURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        } catch {
            Log.claude.error("Claude introspection read failed at \(configURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var names: [String] = []
        if let topLevel = json["mcpServers"] as? [String: Any] {
            names.append(contentsOf: topLevel.keys.sorted())
        }
        if let projects = json["projects"] as? [String: Any],
           let projectEntry = projects[projectRoot.path] as? [String: Any],
           let perProject = projectEntry["mcpServers"] as? [String: Any] {
            for name in perProject.keys.sorted() where !names.contains(name) {
                names.append(name)
            }
        }
        return names
    }

    /// Reads `<projectRoot>/.mcp.json`'s `mcpServers`.
    private func readProjectMCPServerNames(projectRoot: URL) -> [String] {
        let configURL = projectRoot.appendingPathComponent(".mcp.json")
        let data: Data
        do {
            data = try Data(contentsOf: configURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        } catch {
            Log.claude.error("Claude introspection read failed at \(configURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = json["mcpServers"] as? [String: Any] else {
            return []
        }
        return servers.keys.sorted()
    }

    // MARK: - Token usage

    /// Reads every `*.jsonl` transcript under
    /// `~/.claude/projects/<encoded-root>/` and sums their token usage.
    /// Returns nil when the directory doesn't exist or has no transcripts —
    /// distinct from a zeroed `TokenUsage`, so the card can hide the row
    /// entirely rather than showing "0 tokens".
    ///
    /// Streams one file at a time: each file's content is read and summed
    /// individually, and only the running int `TokenUsage` totals are
    /// carried across files — never a combined `[String]` of every file's
    /// lines. For a project with hundreds of MB of transcripts, this bounds
    /// peak transient memory to roughly one file's contents instead of the
    /// sum of all of them.
    ///
    /// `isCancelled` is polled between files (not mid-file) so a cancelled
    /// refresh on a heavy project can bail before reading further files
    /// rather than paying the full I/O cost. This is best-effort: a single
    /// very large file is still read to completion once started.
    private func readTokenUsage(projectRoot: URL, home: URL, isCancelled: @Sendable () -> Bool = { false }) -> TokenUsage? {
        let jsonlFiles = transcriptFiles(projectRoot: projectRoot, home: home)
        guard !jsonlFiles.isEmpty else { return nil }

        var usage = TokenUsage(input: 0, output: 0, cache: 0)
        for file in jsonlFiles {
            if isCancelled() { break }
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: "\n")
            TokenAggregator.accumulate(jsonlLines: lines, into: &usage)
        }
        return usage
    }

    /// Every `*.jsonl` transcript under `~/.claude/projects/<encoded-root>/`,
    /// unordered. Empty (never throws) when the directory doesn't exist or
    /// listing fails — shared by both token aggregation and current-model
    /// extraction below.
    private func transcriptFiles(projectRoot: URL, home: URL) -> [URL] {
        let encoded = ClaudePathEncoder.encode(projectRoot.path)
        let transcriptsDir = home.appendingPathComponent(".claude/projects/\(encoded)", isDirectory: true)

        let fm = FileManager.default
        let entries: [URL]
        do {
            entries = try fm.contentsOfDirectory(at: transcriptsDir, includingPropertiesForKeys: nil)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        } catch {
            Log.claude.error("Claude introspection listing failed at \(transcriptsDir.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }
        return entries.filter { $0.pathExtension == "jsonl" }
    }

    // MARK: - Current model

    /// The model actually used in the most recent session: the newest
    /// `.jsonl` transcript (by modification date), scanned from its last
    /// line backwards for the first line carrying `message.model`. Nil when
    /// there are no transcripts, or none of their lines carry a model —
    /// best-effort, same contract as token aggregation. Honors `isCancelled`
    /// before the read for the same reason `readTokenUsage` does: a cancelled
    /// refresh should not pay for a heavy transcript it will discard.
    private func readCurrentModel(
        projectRoot: URL, home: URL, isCancelled: @Sendable () -> Bool
    ) -> String? {
        guard !isCancelled() else { return nil }
        let jsonlFiles = transcriptFiles(projectRoot: projectRoot, home: home)
        guard let newest = newestFile(jsonlFiles), !isCancelled() else { return nil }
        guard let content = try? String(contentsOf: newest, encoding: .utf8) else { return nil }

        let lines = content.components(separatedBy: "\n")
        for line in lines.reversed() {
            if let model = modelId(fromLine: line) {
                return model
            }
        }
        return nil
    }

    private func newestFile(_ files: [URL]) -> URL? {
        files.max { modificationDate(of: $0) < modificationDate(of: $1) }
    }

    private func modificationDate(of file: URL) -> Date {
        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
        return (attributes?[.modificationDate] as? Date) ?? .distantPast
    }

    private func modelId(fromLine line: String) -> String? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let model = message["model"] as? String else {
            return nil
        }
        return model
    }
}
