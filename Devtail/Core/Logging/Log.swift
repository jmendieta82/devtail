//
//  Log.swift
//  Devtail
//
//  Central unified-logging handles, one per subsystem area. Local-only by
//  design (zero-telemetry rule): lines go to the unified log, nowhere else.
//  PersistenceController predates this and keeps its own file-private
//  `persistence` logger.
//

import os.log

// nonisolated: loggers are consumed from off-main code too (e.g. the file
// search walker), and Logger is Sendable — no reason to pin them to MainActor.
nonisolated enum Log {
    private static let subsystem = "com.jamodev.Devtail"

    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let migration = Logger(subsystem: subsystem, category: "migration")
    static let git = Logger(subsystem: subsystem, category: "git")
    static let claude = Logger(subsystem: subsystem, category: "claude")
    static let search = Logger(subsystem: subsystem, category: "search")
    static let files = Logger(subsystem: subsystem, category: "files")
    static let store = Logger(subsystem: subsystem, category: "store")
}
