import SwiftUI

/// Side panel view: lazy project file tree. File clicks open viewer tabs.
struct FileTreeColumn: View {
    let session: WorkspaceSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DevtailTokens.Spacing.gapMedium) {
                    SectionHeader(title: "Files")
                    Spacer()
                    iconButton("arrow.clockwise", help: "Sync the file tree") {
                        session.fileTree.reloadRoot()
                    }
                    iconButton("arrow.up.forward.square", help: "Reveal the project folder in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([session.root])
                    }
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

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(DevtailTokens.Typography.captionSmall)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.icon)
        .foregroundStyle(DevtailTokens.Colors.accentPrimary)
        .help(help)
    }
}

private struct FileTreeNodeRow: View {
    let node: FileTreeNode
    let session: WorkspaceSession

    private var icon: FileIconMap.Icon {
        node.entry.isDirectory ? FileIconMap.folder : FileIconMap.icon(for: node.entry.name)
    }

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
                    Image(systemName: icon.symbol)
                        .font(.system(size: 11))
                        .foregroundStyle(icon.color)
                        .frame(width: 14)
                    Text(node.entry.name)
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .buttonStyle(.icon)
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
