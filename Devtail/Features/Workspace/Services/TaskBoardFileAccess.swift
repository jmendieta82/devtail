//
//  TaskBoardFileAccess.swift
//  Devtail
//
//  Injection seam for TaskBoardStore: the production implementation does
//  real disk I/O (off the main actor — these are async and the work is
//  plain FileManager/String I/O), tests substitute an in-memory double.
//  Mirrors the GitStatusReading seam rationale.
//

import Foundation
import os.log

protocol TaskBoardFileAccessing: Sendable {
    func read(at url: URL) async -> String?
    func write(_ text: String, to url: URL) async -> Bool
    func append(_ text: String, to url: URL) async -> Bool
}

struct TaskBoardFileAccess: TaskBoardFileAccessing {

    init() {}

    func read(at url: URL) async -> String? {
        await Self.onIOQueue {
            try? String(contentsOf: url, encoding: .utf8)
        }
    }

    /// Creates intermediate directories (.devtail/) as needed. Atomic so a
    /// crash mid-write never leaves a truncated board.
    func write(_ text: String, to url: URL) async -> Bool {
        await Self.onIOQueue {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try text.write(to: url, atomically: true, encoding: .utf8)
                return true
            } catch {
                Log.store.error("task board write failed at \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
    }

    func append(_ text: String, to url: URL) async -> Bool {
        await Self.onIOQueue {
            let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try (existing + text).write(to: url, atomically: true, encoding: .utf8)
                return true
            } catch {
                Log.store.error("task board append failed at \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
    }

    /// Runs blocking file I/O on a utility queue and resumes the caller —
    /// same shape as GitStatusReader.run's continuation bridge.
    private static func onIOQueue<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: work())
            }
        }
    }
}
