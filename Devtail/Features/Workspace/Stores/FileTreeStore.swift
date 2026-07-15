import Foundation

@Observable
final class FileTreeNode: Identifiable {
    let entry: DirectoryEntry
    let depth: Int
    var isExpanded = false
    var children: [FileTreeNode]?      // nil = never loaded
    var loadError: String?

    var id: String { entry.url.path }
    var isDotfile: Bool { entry.name.hasPrefix(".") }

    init(entry: DirectoryEntry, depth: Int) {
        self.entry = entry
        self.depth = depth
    }
}

@Observable
final class FileTreeStore {
    /// No real project is deeper than this; bail instead of walking forever.
    static let maxDepth = 32

    let root: URL
    private let lister: DirectoryLister
    private(set) var rootNodes: [FileTreeNode]?
    private(set) var rootError: String?

    init(root: URL, lister: DirectoryLister) {
        self.root = root
        self.lister = lister
    }

    func loadRootIfNeeded() {
        guard rootNodes == nil, rootError == nil else { return }
        // Relative URLs never converge when walked (see GitBranchDetector incident).
        guard root.path.hasPrefix("/") else {
            rootError = "Invalid project root"
            return
        }
        do {
            rootNodes = try lister.list(root).map { FileTreeNode(entry: $0, depth: 0) }
        } catch {
            rootError = error.localizedDescription
        }
    }

    func toggleExpansion(of node: FileTreeNode) {
        guard node.entry.isDirectory else { return }
        node.isExpanded.toggle()
        guard node.isExpanded, node.children == nil else { return }
        guard node.depth < Self.maxDepth else {
            node.loadError = "Folder is too deeply nested"
            return
        }
        do {
            node.children = try lister.list(node.entry.url).map {
                FileTreeNode(entry: $0, depth: node.depth + 1)
            }
            node.loadError = nil
        } catch {
            node.loadError = error.localizedDescription
        }
    }
}
