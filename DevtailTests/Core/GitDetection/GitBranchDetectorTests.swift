//
//  GitBranchDetectorTests.swift
//  DevtailTests
//
//  Tests both the pure HEAD parser (no filesystem) and the full
//  walk-up-find-`.git`-and-read-HEAD flow against temp folders that
//  simulate real git layouts.
//

import Testing
import Foundation
@testable import Devtail

@Suite("GitBranchDetector")
struct GitBranchDetectorTests {

    // MARK: - Fixture plumbing

    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-git-detector-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func cleanup(_ folder: URL) {
        try? FileManager.default.removeItem(at: folder)
    }

    /// Writes a `.git/HEAD` file with the given contents under `folder`.
    private func makeGitDir(in folder: URL, head: String) throws {
        let gitDir = folder.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
        let headURL = gitDir.appendingPathComponent("HEAD")
        try head.data(using: .utf8)!.write(to: headURL)
    }

    // MARK: - parseHead — symbolic refs

    @Test("parseHead returns branch name from a normal symbolic ref")
    func parseHeadNormalBranch() {
        let result = GitBranchDetector.parseHead("ref: refs/heads/main\n")
        #expect(result == "main")
    }

    @Test("parseHead handles slash-separated branch names like feature/login")
    func parseHeadSlashedBranch() {
        let result = GitBranchDetector.parseHead("ref: refs/heads/feature/login\n")
        #expect(result == "feature/login")
    }

    @Test("parseHead trims trailing whitespace and CRLF line endings")
    func parseHeadTrimming() {
        let result = GitBranchDetector.parseHead("ref: refs/heads/develop\r\n   ")
        #expect(result == "develop")
    }

    @Test("parseHead handles non-heads refs by taking the last path component")
    func parseHeadGenericRef() {
        // A user could end up with HEAD pointing into refs/tags/ or
        // refs/remotes/. We don't model those richly — last segment is
        // good enough for the read-only badge use case.
        let result = GitBranchDetector.parseHead("ref: refs/tags/v1.2.3\n")
        #expect(result == "v1.2.3")
    }

    // MARK: - parseHead — detached HEAD

    @Test("parseHead returns short SHA prefixed with @ for detached HEAD")
    func parseHeadDetached() {
        let sha = "abc1234567890def1234567890abcdef12345678"
        let result = GitBranchDetector.parseHead(sha + "\n")
        #expect(result == "@abc1234")
    }

    @Test("parseHead accepts SHA-256 hashes (newer git repos)")
    func parseHeadSha256Detached() {
        // 64-char hex string. SHA-256 became real in git 2.29.
        let sha = String(repeating: "a", count: 64)
        let result = GitBranchDetector.parseHead(sha + "\n")
        #expect(result == "@aaaaaaa")
    }

    @Test("parseHead handles uppercase hex characters in SHA")
    func parseHeadUppercaseSha() {
        let sha = "ABC1234567890DEF1234567890ABCDEF12345678"
        let result = GitBranchDetector.parseHead(sha)
        #expect(result == "@ABC1234")
    }

    // MARK: - parseHead — malformed input

    @Test("parseHead returns nil for empty string")
    func parseHeadEmpty() {
        #expect(GitBranchDetector.parseHead("") == nil)
        #expect(GitBranchDetector.parseHead("   \n") == nil)
    }

    @Test("parseHead returns nil for garbage that is neither ref nor SHA")
    func parseHeadGarbage() {
        #expect(GitBranchDetector.parseHead("hello world") == nil)
        #expect(GitBranchDetector.parseHead("xyz1234") == nil)
    }

    @Test("parseHead returns nil for almost-SHA strings of wrong length")
    func parseHeadAlmostSha() {
        // 39 chars instead of 40 — clearly not a valid SHA-1.
        let almost = String(repeating: "a", count: 39)
        #expect(GitBranchDetector.parseHead(almost) == nil)
    }

    @Test("parseHead returns nil when ref: prefix has no path")
    func parseHeadEmptyRef() {
        #expect(GitBranchDetector.parseHead("ref: ") == nil)
        #expect(GitBranchDetector.parseHead("ref: refs/heads/") == nil)
    }

    // MARK: - detectBranch — full walk

    @Test("detectBranch reads HEAD when .git is a direct child of the folder")
    func detectBranchDirectChild() throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try makeGitDir(in: folder, head: "ref: refs/heads/main\n")

        let result = GitBranchDetector().detectBranch(in: folder)

        #expect(result == "main")
    }

    @Test("detectBranch walks up from a nested subfolder until it finds .git")
    func detectBranchWalksUp() throws {
        // Real-world case: workspace pane points at frontend/, and .git
        // lives at the project root above it.
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try makeGitDir(in: folder, head: "ref: refs/heads/develop\n")

        let nested = folder.appendingPathComponent("frontend/src/components")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        let result = GitBranchDetector().detectBranch(in: nested)

        #expect(result == "develop")
    }

    @Test("detectBranch returns nil when no .git is found anywhere up the tree")
    func detectBranchNoGitAnywhere() throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        // No git anywhere. The walk will hit "/" eventually and bail.

        let result = GitBranchDetector().detectBranch(in: folder)

        #expect(result == nil)
    }

    @Test("detectBranch handles a folder that does not exist by returning nil")
    func detectBranchMissingFolder() {
        let bogus = URL(fileURLWithPath: "/tmp/devtail-does-not-exist-\(UUID().uuidString)")
        let result = GitBranchDetector().detectBranch(in: bogus)

        #expect(result == nil)
    }

    @Test("detectBranch returns short SHA for a detached-HEAD repository")
    func detectBranchDetached() throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        let sha = "1a2b3c4d5e6f7890abcdef1234567890abcdef12"
        try makeGitDir(in: folder, head: sha + "\n")

        let result = GitBranchDetector().detectBranch(in: folder)

        #expect(result == "@1a2b3c4")
    }

    @Test("detectBranch follows a .git file with gitdir: prefix (worktree style)")
    func detectBranchGitFileWorktree() throws {
        // Simulate `git worktree add` layout: the worktree folder has a
        // `.git` FILE that points at the real gitdir living elsewhere.
        let workspace = try makeFolder()
        defer { cleanup(workspace) }

        let realGitDir = workspace.appendingPathComponent("real-gitdir")
        try FileManager.default.createDirectory(at: realGitDir, withIntermediateDirectories: true)
        try "ref: refs/heads/feature/x\n"
            .data(using: .utf8)!
            .write(to: realGitDir.appendingPathComponent("HEAD"))

        let worktreeFolder = workspace.appendingPathComponent("worktree")
        try FileManager.default.createDirectory(at: worktreeFolder, withIntermediateDirectories: true)
        // .git file with absolute path to the real gitdir.
        let gitFile = worktreeFolder.appendingPathComponent(".git")
        try "gitdir: \(realGitDir.path)\n"
            .data(using: .utf8)!
            .write(to: gitFile)

        let result = GitBranchDetector().detectBranch(in: worktreeFolder)

        #expect(result == "feature/x")
    }

    // MARK: - Pathological URLs (regression: infinite walk → 44GB OOM)

    @Test("empty-path URL returns nil instead of walking forever", .timeLimit(.minutes(1)))
    func emptyPathURLReturnsNil() {
        // URL(fileURLWithPath: "") yields a RELATIVE "./" URL whose
        // deletingLastPathComponent grows "../" forever — the walk must
        // reject it up front, not spin allocating.
        #expect(GitBranchDetector().detectBranch(in: URL(fileURLWithPath: "")) == nil)
    }

    @Test("relative file URL returns nil instead of walking forever", .timeLimit(.minutes(1)))
    func relativeURLReturnsNil() {
        let relative = URL(string: "file:some/relative/dir")!
        #expect(GitBranchDetector().detectBranch(in: relative) == nil)
    }
}
