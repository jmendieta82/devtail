//
//  ProcessTeardown.swift
//  Devtail
//
//  SIGTERM -> grace -> SIGKILL against a process group, with injectable
//  signal delivery and scheduling so the sequence is unit-testable.
//

import Foundation
import os.log

struct ProcessTeardown {
    /// Signal delivery; production is `killpg`. Non-zero return means failure
    /// (errno holds the reason) — logged, never fatal.
    var signal: (pid_t, Int32) -> Int32
    /// Deferred main-actor execution; production is the main queue.
    var schedule: (TimeInterval, @escaping @MainActor () -> Void) -> Void

    static let grace: TimeInterval = 3

    static let production = ProcessTeardown(
        signal: { killpg($0, $1) },
        schedule: { delay, block in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                MainActor.assumeIsolated(block)
            }
        }
    )

    /// Staged termination: SIGTERM now, SIGKILL after `grace` unless
    /// `isExited` reports the child already left.
    func terminate(group pid: pid_t, isExited: @escaping @MainActor () -> Bool) {
        if signal(pid, SIGTERM) != 0 {
            Log.lifecycle.error("killpg(\(pid, privacy: .public), SIGTERM) failed: errno \(errno, privacy: .public)")
        }
        schedule(Self.grace) {
            guard !isExited() else { return }
            Log.lifecycle.info("Grace expired for process group \(pid, privacy: .public); escalating to SIGKILL")
            if self.signal(pid, SIGKILL) != 0 {
                Log.lifecycle.error("killpg(\(pid, privacy: .public), SIGKILL) failed: errno \(errno, privacy: .public)")
            }
        }
    }

    /// Immediate SIGKILL, no grace — the quit-deadline escalation for groups
    /// that ignored `terminate`'s SIGTERM.
    func kill(group pid: pid_t) {
        if signal(pid, SIGKILL) != 0 {
            Log.lifecycle.error("killpg(\(pid, privacy: .public), SIGKILL) failed: errno \(errno, privacy: .public)")
        }
    }
}
