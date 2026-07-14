//
//  GitRemoteDetector.swift
//  Devtail
//
//  Reads a repository's `origin` remote URL by parsing `.git/config`
//  directly — same sandbox-safe approach as GitBranchDetector. We cannot
//  shell out to `git remote get-url` under App Sandbox, so we parse the
//  INI-style config file instead.
//
//  Behavior:
//    - Walks up from the given folder looking for a `.git` entry, reusing
//      the same logic as GitBranchDetector (handles worktrees/submodules
//      via the `gitdir:` pointer file).
//    - Parses `.git/config` for the `[remote "origin"]` section's `url`.
//    - Normalizes the URL to a web-browsable form:
//        * strips trailing `.git`
//        * rewrites SSH form `git@host:org/repo` to `https://host/org/repo`
//    - Derives a host-aware label (GitHub / GitLab / Bitbucket / Repository).
//    - Returns `nil` when no repo is found, no remote is configured, or the
//      URL cannot be parsed. Best-effort — the caller decides whether to
//      surface nothing or a generic fallback.
//

import Foundation

struct GitRemoteInfo: Equatable, Sendable {
    /// Web-browsable URL (always http/https). Safe to hand to NSWorkspace.
    let webURL: String
    /// Suggested label based on the host — "GitHub", "GitLab", "Bitbucket",
    /// or the generic "Repository" when the host isn't recognized.
    let label: String
}

struct GitRemoteDetector: Sendable {

    init() {}

    /// Returns the origin remote URL info for the repository containing
    /// `folder`, or `nil` when the folder is not inside a git repo / the
    /// repo has no origin remote / the config is malformed.
    func detectRemote(in folder: URL) -> GitRemoteInfo? {
        guard let gitDir = Self.findGitDirectory(startingFrom: folder) else {
            return nil
        }
        let configURL = gitDir.appendingPathComponent("config")
        guard let contents = try? String(contentsOf: configURL, encoding: .utf8) else {
            return nil
        }
        guard let rawURL = Self.parseOriginURL(contents) else {
            return nil
        }
        guard let webURL = Self.normalizeToWebURL(rawURL) else {
            return nil
        }
        return GitRemoteInfo(webURL: webURL, label: Self.label(forWebURL: webURL))
    }

    // MARK: - .git discovery (mirrors GitBranchDetector)

    private static func findGitDirectory(startingFrom folder: URL) -> URL? {
        let fm = FileManager.default
        var current = folder.standardizedFileURL

        while true {
            let candidate = current.appendingPathComponent(".git")
            var isDirectory: ObjCBool = false
            if fm.fileExists(atPath: candidate.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    return candidate
                }
                if let resolved = resolveGitFile(at: candidate, relativeTo: current) {
                    return resolved
                }
                return nil
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                return nil
            }
            current = parent
        }
    }

    private static func resolveGitFile(at fileURL: URL, relativeTo base: URL) -> URL? {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }
        let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "gitdir:"
        guard trimmed.hasPrefix(prefix) else { return nil }

        let pathPart = trimmed
            .dropFirst(prefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pathPart.isEmpty else { return nil }

        if pathPart.hasPrefix("/") {
            return URL(fileURLWithPath: pathPart).standardizedFileURL
        }
        return base.appendingPathComponent(pathPart).standardizedFileURL
    }

    // MARK: - Config parsing

    /// Finds the `url = ...` line inside the `[remote "origin"]` section
    /// of a git config file. Returns the raw URL verbatim (SSH or HTTPS)
    /// or nil when no origin remote is configured.
    ///
    /// Internal-static so it can be exercised by unit tests without
    /// touching the filesystem.
    static func parseOriginURL(_ configContents: String) -> String? {
        var inOriginSection = false
        for rawLine in configContents.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") {
                continue
            }
            if line.hasPrefix("[") {
                // New section header — flip the flag based on whether it's
                // the one we want. Match both `[remote "origin"]` and the
                // alternate subsection-quoted form `[remote "origin"]`
                // (case-insensitive on the section name).
                inOriginSection = Self.isOriginRemoteHeader(line)
                continue
            }
            if inOriginSection, let value = Self.extractURLValue(from: line) {
                return value
            }
        }
        return nil
    }

    private static func isOriginRemoteHeader(_ line: String) -> Bool {
        // Accepts any of:
        //   [remote "origin"]
        //   [remote "Origin"]
        //   [REMOTE "origin"]
        // Rejects other subsections like [remote "upstream"].
        let compact = line
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        return compact == "[remote\"origin\"]"
    }

    private static func extractURLValue(from line: String) -> String? {
        // Config keys are case-insensitive per git docs — "URL", "Url",
        // "url" all valid.
        let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
        guard key == "url" else { return nil }
        let value = parts[1].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    // MARK: - URL normalization

    /// Converts a raw git remote URL (SSH or HTTPS) into a web-browsable
    /// https:// URL suitable for NSWorkspace.open. Returns nil for unknown
    /// forms rather than producing a broken URL.
    static func normalizeToWebURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // SSH form: git@host:path/to/repo(.git)?
        if let scp = parseScpStyle(trimmed) {
            return "https://\(scp.host)/\(stripDotGit(scp.path))"
        }

        // ssh://user@host/path form — treat like SSH.
        if trimmed.hasPrefix("ssh://"), let url = URL(string: trimmed),
           let host = url.host {
            let path = url.path.drop(while: { $0 == "/" })
            return "https://\(host)/\(stripDotGit(String(path)))"
        }

        // git://host/path form.
        if trimmed.hasPrefix("git://"), let url = URL(string: trimmed),
           let host = url.host {
            let path = url.path.drop(while: { $0 == "/" })
            return "https://\(host)/\(stripDotGit(String(path)))"
        }

        // https:// or http:// — pass through, strip `.git`.
        if trimmed.hasPrefix("https://") || trimmed.hasPrefix("http://") {
            return stripDotGit(trimmed)
        }

        return nil
    }

    /// Parses `git@host:path` (scp-style) URLs. Returns (host, path) or nil.
    private static func parseScpStyle(_ raw: String) -> (host: String, path: String)? {
        // Must contain exactly one `:` that is NOT part of a scheme
        // (i.e. no `://` in the string). Minimum shape: `user@host:path`.
        guard !raw.contains("://") else { return nil }
        guard let atIndex = raw.firstIndex(of: "@") else { return nil }
        let afterAt = raw.index(after: atIndex)
        guard let colonIndex = raw[afterAt...].firstIndex(of: ":") else { return nil }
        let host = String(raw[afterAt..<colonIndex])
        let path = String(raw[raw.index(after: colonIndex)...])
        guard !host.isEmpty, !path.isEmpty else { return nil }
        return (host, path)
    }

    private static func stripDotGit(_ url: String) -> String {
        url.hasSuffix(".git") ? String(url.dropLast(4)) : url
    }

    // MARK: - Labeling

    /// Derives a short label from the web URL, preferring the repository
    /// name (last path component) so multiple repos on the same host stay
    /// distinguishable at a glance. Falls back to the host name, then to
    /// "Repository" when nothing useful can be extracted.
    ///
    /// Examples:
    ///   https://github.com/inclusiva/frontend   → "frontend"
    ///   https://github.com/inclusiva/backend    → "backend"
    ///   https://github.com/                     → "GitHub"
    ///   (unparseable)                           → "Repository"
    static func label(forWebURL webURL: String) -> String {
        guard let url = URL(string: webURL) else { return "Repository" }

        // Prefer the repo name — last non-empty path component.
        let components = url.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        if let repoName = components.last, !repoName.isEmpty {
            return repoName
        }

        // Empty path → fall back to the host family.
        if let host = url.host?.lowercased() {
            if host.contains("github.com") { return "GitHub" }
            if host.contains("gitlab.com") { return "GitLab" }
            if host.contains("bitbucket.org") { return "Bitbucket" }
            if host.contains("gitlab.") { return "GitLab" } // self-hosted
            if host.contains("bitbucket.") { return "Bitbucket" }
            return host
        }

        return "Repository"
    }
}
