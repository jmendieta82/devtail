//
//  EnvFileSaver.swift
//  Devtail
//
//  Atomic write path for env-file editing, plus on-disk modification-date
//  conflict detection: the only write surface the read-only file viewer
//  gains. Kept as a small testable service (real temp-dir tests, no
//  FileManager mocking) rather than embedding this logic in the view.
//

import Foundation

enum EnvFileSaverError: Error {
    case encodingFailed
}

enum EnvFileSaver {
    /// The file's current on-disk modification date, or nil if it can't be
    /// read (missing file, unreadable metadata).
    static func modificationDate(at path: String) -> Date? {
        let url = URL(fileURLWithPath: path)
        return (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    /// True when the file's on-disk modification date no longer matches the
    /// date recorded at load time — either it was edited externally, or it
    /// disappeared entirely. Nil-vs-anything (disappeared file) also counts
    /// as a conflict: there is nothing safe to overwrite blindly.
    static func hasConflict(path: String, recordedModificationDate: Date) -> Bool {
        guard let current = modificationDate(at: path) else { return true }
        return current != recordedModificationDate
    }

    /// Writes `text` to `path` atomically (write-to-temp-then-rename via
    /// `Data.write(options: .atomic)`), so a crash or concurrent read never
    /// observes a partially written file.
    static func save(text: String, to path: String) throws {
        guard let data = text.data(using: .utf8) else {
            throw EnvFileSaverError.encodingFailed
        }
        let url = URL(fileURLWithPath: path)
        try data.write(to: url, options: .atomic)
    }
}
