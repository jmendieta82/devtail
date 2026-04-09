//
//  GitBranchDetector.swift
//  Devtail
//
//  Reads the current branch from a folder by parsing `.git/HEAD` directly,
//  without shelling out to the `git` binary. The motivation is App Sandbox:
//  Devtail cannot run arbitrary subprocesses without entitlements that the
//  Mac App Store rejects, and `git rev-parse --abbrev-ref HEAD` would
//  require exactly that. Reading `.git/HEAD` is just a small text file,
//  works inside the sandbox, and covers 99% of real-world cases.
//
//  Behavior:
//    - Walks UP from the given folder looking for a `.git` entry. This
//      handles the common case where the user pointed a workspace pane
//      at a subfolder of a git repo (frontend/, backend/, etc.).
//    - When `.git` is a directory, reads `.git/HEAD`.
//    - When `.git` is a file (git worktrees, submodules), reads its
//      `gitdir: <path>` line and follows it.
//    - Parses HEAD: `ref: refs/heads/<name>` → returns `<name>`.
//      Bare SHA → detached HEAD, returns the first 7 chars prefixed with
//      `@` so the UI can render it as a short hash.
//    - Anything malformed or absent → returns nil. The caller decides
//      whether to show "no git" or hide the slot entirely.
//
//  Concurrency: pure value type, marked Sendable, performs only synchronous
//  filesystem reads. Safe to call from any actor — but kept synchronous on
//  purpose: parsing 4KB of text is sub-millisecond and not worth the cost
//  of an async hop. The caller invokes it from the @MainActor view body
//  without ceremony.
//

import Foundation

struct GitBranchDetector: Sendable {

    init() {}

    /// Returns a short, human-readable branch label for the git
    /// repository that contains `folder`, or `nil` when the folder is
    /// not inside a git repo (or the repo metadata is unreadable).
    ///
    /// - Parameter folder: Absolute file URL to inspect. May be the
    ///                     repository root or a nested subfolder.
    /// - Returns:
    ///   - On a normal branch: the branch name (e.g. `"main"`,
    ///     `"feature/auth"`).
    ///   - On detached HEAD: `"@<short-sha>"` where short-sha is the
    ///     first 7 characters of the commit hash.
    ///   - When no `.git` is found, or HEAD is unreadable / malformed:
    ///     `nil`.
    func detectBranch(in folder: URL) -> String? {
        guard let gitDir = Self.findGitDirectory(startingFrom: folder) else {
            return nil
        }

        let headURL = gitDir.appendingPathComponent("HEAD")
        guard let headContents = try? String(contentsOf: headURL, encoding: .utf8) else {
            return nil
        }

        return Self.parseHead(headContents)
    }

    // MARK: - Internals

    /// Walks up the filesystem from `folder` looking for a `.git` entry.
    /// Returns the resolved git directory: either the `.git` folder
    /// itself, or — when `.git` is a regular file (worktrees, submodules)
    /// — the directory referenced by its `gitdir:` line.
    ///
    /// Stops at the filesystem root. Symbolic links are followed via
    /// `URL.standardizedFileURL`.
    private static func findGitDirectory(startingFrom folder: URL) -> URL? {
        let fm = FileManager.default
        var current = folder.standardizedFileURL

        // Walk parents until we hit "/" (which has no parent in URL terms,
        // detected by lastPathComponent == "/" or empty path components).
        while true {
            let candidate = current.appendingPathComponent(".git")
            var isDirectory: ObjCBool = false
            if fm.fileExists(atPath: candidate.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    return candidate
                }
                // `.git` exists but is a file — typically a worktree or
                // submodule pointer. Read it for the `gitdir:` line.
                if let resolved = resolveGitFile(at: candidate, relativeTo: current) {
                    return resolved
                }
                return nil
            }

            // Move up. URL.deletingLastPathComponent of "/" returns "/"
            // again — we have to break to avoid an infinite loop.
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                return nil
            }
            current = parent
        }
    }

    /// Parses a `.git` file (not directory) and returns the absolute URL
    /// of the actual git directory it points at. Format is one line:
    ///
    ///     gitdir: <relative or absolute path>
    ///
    /// Used by submodules and `git worktree add`.
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

        // Absolute path → use as-is. Relative → resolve against the
        // directory that contained the .git file.
        if pathPart.hasPrefix("/") {
            return URL(fileURLWithPath: pathPart).standardizedFileURL
        }
        return base.appendingPathComponent(pathPart).standardizedFileURL
    }

    /// Interprets the contents of a `.git/HEAD` file. Returns either a
    /// branch name (e.g. "main", "feature/login"), a detached-HEAD
    /// label ("@1a2b3c4"), or nil for unrecognized formats.
    ///
    /// Made internal-`static` so the parser can be unit-tested without
    /// touching the filesystem at all.
    static func parseHead(_ contents: String) -> String? {
        let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Symbolic ref form: "ref: refs/heads/<branch-name>".
        let symbolicPrefix = "ref: refs/heads/"
        if trimmed.hasPrefix(symbolicPrefix) {
            let name = trimmed.dropFirst(symbolicPrefix.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : String(name)
        }

        // Some refs live outside refs/heads/ (tags, remotes). We render
        // them with their last path component to keep things compact.
        let genericRefPrefix = "ref: "
        if trimmed.hasPrefix(genericRefPrefix) {
            let refPath = trimmed.dropFirst(genericRefPrefix.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let last = refPath.split(separator: "/").last else { return nil }
            return last.isEmpty ? nil : String(last)
        }

        // Bare SHA → detached HEAD. Validate it looks like a hex hash
        // before treating it as one (40 chars, hex only) so a corrupted
        // file doesn't get rendered as a "branch".
        if isHexSha(trimmed) {
            let short = String(trimmed.prefix(7))
            return "@\(short)"
        }

        return nil
    }

    /// True when `string` is exactly 40 lowercase or uppercase hex chars
    /// — the canonical git SHA-1 length. SHA-256 (64 chars) is also
    /// allowed because newer repos may use it.
    private static func isHexSha(_ string: String) -> Bool {
        let count = string.count
        guard count == 40 || count == 64 else { return false }
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return string.unicodeScalars.allSatisfy { hexCharacters.contains($0) }
    }
}
