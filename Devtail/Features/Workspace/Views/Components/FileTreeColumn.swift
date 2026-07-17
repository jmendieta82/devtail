import SwiftUI

/// Side panel view: lazy project file tree. File clicks open viewer tabs.
struct FileTreeColumn: View {
    let session: WorkspaceSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    SectionHeader(title: "Files")
                    Spacer()
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([session.root])
                    } label: {
                        Label("Open in Finder", systemImage: "arrow.up.forward.square")
                            .font(DevtailTokens.Typography.captionSmall)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DevtailTokens.Colors.accentPrimary)
                    .help("Reveal the project folder in Finder")
                }
                if let error = session.fileTree.rootError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                } else if let nodes = session.fileTree.rootNodes {
                    ForEach(nodes) { node in
                        FileTreeNodeRow(node: node, session: session)
                    }
                }
            }
            .padding(DevtailTokens.Spacing.cardPadding)
        }
        .onAppear { session.fileTree.loadRootIfNeeded() }
    }
}

private struct FileTreeNodeRow: View {
    let node: FileTreeNode
    let session: WorkspaceSession

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: activate) {
                HStack(spacing: 4) {
                    if node.entry.isDirectory {
                        Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    } else {
                        Spacer().frame(width: 10)
                    }
                    Image(systemName: node.entry.isDirectory ? "folder" : "doc.text")
                        .font(.system(size: 10))
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    Text(node.entry.name)
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .buttonStyle(.plain)
            .opacity(node.isDotfile ? 0.5 : 1)
            .padding(.leading, CGFloat(node.depth) * 12)

            if let error = node.loadError, node.isExpanded {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .padding(.leading, CGFloat(node.depth + 1) * 12)
            }
            if node.isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileTreeNodeRow(node: child, session: session)
                }
            }
        }
    }

    private func activate() {
        if node.entry.isDirectory {
            session.fileTree.toggleExpansion(of: node)
        } else {
            session.openFile(at: node.entry.url.path)
        }
    }
}
