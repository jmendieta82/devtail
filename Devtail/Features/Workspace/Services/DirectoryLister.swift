import Foundation

nonisolated struct DirectoryEntry: Hashable, Sendable {
    let name: String
    let url: URL
    let isDirectory: Bool
}

/// Nonisolated so the file-search walk can list directories off the main
/// actor. FileManager is thread-safe for directory reads.
nonisolated protocol DirectoryLister: Sendable {
    func list(_ directory: URL) throws -> [DirectoryEntry]
}

nonisolated struct FileManagerDirectoryLister: DirectoryLister {
    func list(_ directory: URL) throws -> [DirectoryEntry] {
        try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [])
            .map { url in
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return DirectoryEntry(name: url.lastPathComponent, url: url, isDirectory: isDirectory)
            }
            .sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
    }
}
