import Foundation

struct DirectoryEntry: Hashable {
    let name: String
    let url: URL
    let isDirectory: Bool
}

protocol DirectoryLister {
    func list(_ directory: URL) throws -> [DirectoryEntry]
}

struct FileManagerDirectoryLister: DirectoryLister {
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
