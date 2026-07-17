//
//  GitStatusReader.swift
//  Devtail
//
//  First stdout-capturing Process wrapper in the codebase. Everything else
//  under Core/GitDetection reads repo metadata files directly (sandbox-safe,
//  no shell) — that approach cannot answer "how many local branches" or
//  "am I ahead/behind upstream" without reimplementing large chunks of git's
//  ref-walking logic. App Sandbox is OFF for Devtail (see project
//  CLAUDE.md), so shelling out to the real `git` binary is allowed.
//
//  Runs four short-lived `git` invocations via `/usr/bin/git -C <root> ...`,
//  each with a short timeout so a hung repository (e.g. on a stalled network
//  mount) cannot wedge the caller. Every command runs off the main actor —
//  Process launch + pipe read is blocking I/O.
//
//  The PARSING of each command's stdout is extracted to pure static
//  functions (`parseAheadBehind`, `parseBranchCount`, `parsePorcelain`) so
//  the interesting logic is unit-testable without touching a real process
//  or filesystem. `status(in:)` itself is best-effort/manual-tested only —
//  see the design doc.
//

import Foundation
import os.log

/// Snapshot of a git repository's status, as read by `GitStatusReader`.
/// Optional fields (`ahead`/`behind`) are nil when there is no upstream
/// configured for the current branch.
struct GitStatus: Equatable, Sendable {
    let branch: String
    let localBranchCount: Int
    let isDirty: Bool
    let changedFileCount: Int
    let ahead: Int?
    let behind: Int?
}

/// Injection seam for `WorkspaceSession.refreshGitStatus()`: the real
/// implementation shells out to `git` (not headless-testable), so tests
/// substitute a fake conforming to this protocol to verify the
/// assign-on-success / no-assign-when-cancelled wiring without a real
/// process.
protocol GitStatusReading: Sendable {
    func status(in root: URL) async -> GitStatus?
}

struct GitStatusReader: GitStatusReading, Sendable {

    /// Path to the git binary. Fixed to the Xcode Command Line Tools /
    /// system location rather than resolved via `env` — avoids depending on
    /// the user's shell PATH.
    private static let gitPath = "/usr/bin/git"

    init() {}

    /// Runs `git` against `root` and returns a full status snapshot, or nil
    /// when `root` is not a git repository (or git is unavailable / every
    /// invocation fails). Safe to call from any actor — it performs no
    /// synchronous work on the caller's context; all process I/O happens on
    /// a background executor via `async`.
    func status(in root: URL) async -> GitStatus? {
        guard let branchOutput = await Self.run(["rev-parse", "--abbrev-ref", "HEAD"], in: root) else {
            return nil
        }
        let branch = branchOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !branch.isEmpty else { return nil }

        let branchListOutput = await Self.run(["branch", "--format=%(refname:short)"], in: root) ?? ""
        let localBranchCount = Self.parseBranchCount(branchListOutput)

        let porcelainOutput = await Self.run(["status", "--porcelain"], in: root) ?? ""
        let (isDirty, changedFileCount) = Self.parsePorcelain(porcelainOutput)

        var ahead: Int?
        var behind: Int?
        if let aheadBehindOutput = await Self.run(
            ["rev-list", "--count", "--left-right", "@{upstream}...HEAD"], in: root
        ), let parsed = Self.parseAheadBehind(aheadBehindOutput) {
            ahead = parsed.ahead
            behind = parsed.behind
        }

        return GitStatus(
            branch: branch,
            localBranchCount: localBranchCount,
            isDirty: isDirty,
            changedFileCount: changedFileCount,
            ahead: ahead,
            behind: behind
        )
    }

    // MARK: - Process execution

    /// Runs `/usr/bin/git -C <root> <arguments>`, capturing stdout as a
    /// UTF-8 string. Returns nil on a non-zero exit, a launch failure, or
    /// timeout. Off the main actor: `Process` launch and `Pipe` reads are
    /// blocking calls.
    private static func run(_ arguments: [String], in root: URL) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: gitPath)
                process.arguments = ["-C", root.path] + arguments

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    Log.git.error("git \(arguments.joined(separator: " "), privacy: .public) launch failed in \(root.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: nil)
                    return
                }

                // Short timeout guard: terminate a hung invocation (e.g. a
                // repo on a stalled network mount) instead of blocking the
                // caller forever.
                let timeoutWorkItem = DispatchWorkItem {
                    if process.isRunning {
                        Log.git.error("git \(arguments.joined(separator: " "), privacy: .public) timed out in \(root.path, privacy: .public); terminating")
                        process.terminate()
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: timeoutWorkItem)

                // stderr is drained concurrently on its own queue and
                // discarded (unused by any caller). If it were read after
                // stdout instead, a git invocation that writes enough to
                // stderr to fill its pipe buffer (~64KB) would block on the
                // write forever — neither pipe reader may wait on the other,
                // both must run before `waitUntilExit()`.
                let stderrDrained = DispatchSemaphore(value: 0)
                DispatchQueue.global(qos: .userInitiated).async {
                    _ = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    stderrDrained.signal()
                }

                let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                stderrDrained.wait()
                timeoutWorkItem.cancel()

                guard process.terminationStatus == 0 else {
                    Log.git.error("git \(arguments.joined(separator: " "), privacy: .public) exited \(process.terminationStatus, privacy: .public) in \(root.path, privacy: .public)")
                    continuation.resume(returning: nil)
                    return
                }
                let output = String(data: outputData, encoding: .utf8)
                continuation.resume(returning: output)
            }
        }
    }

    // MARK: - Pure parsers (TDD targets)

    /// Parses `git rev-list --count --left-right @{upstream}...HEAD`
    /// output, formatted as `"<behind>\t<ahead>"`. Returns nil for any
    /// malformed input (including the command's own failure output, which
    /// the caller never passes in since `run` already returns nil on
    /// non-zero exit — this guards against unexpected stdout shapes too).
    static func parseAheadBehind(_ output: String) -> (behind: Int, ahead: Int)? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "\t")
        guard parts.count == 2,
              let behind = Int(parts[0]),
              let ahead = Int(parts[1]) else {
            return nil
        }
        return (behind: behind, ahead: ahead)
    }

    /// Parses `git status --porcelain` output: each non-blank line is one
    /// changed file. Dirty when there is at least one such line.
    static func parsePorcelain(_ output: String) -> (isDirty: Bool, count: Int) {
        let count = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .count
        return (isDirty: count > 0, count: count)
    }

    /// Parses `git branch --format=%(refname:short)` output: one local
    /// branch name per non-blank line.
    static func parseBranchCount(_ output: String) -> Int {
        output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .count
    }
}
