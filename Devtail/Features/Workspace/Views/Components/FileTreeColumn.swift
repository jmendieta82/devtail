import SwiftUI

/// Side panel view: lazy project file tree, replaced by a flat file-name
/// search result list while a query is active. File clicks (tree rows and
/// search results alike) open viewer tabs.
struct FileTreeColumn: View {
    let session: WorkspaceSession

    @FocusState private var isSearchFocused: Bool
    /// Keyboard-highlighted row in the search result list; reset whenever
    /// the query changes so a shrunken list can't leave it dangling.
    @State private var selectedResultIndex = 0

    var body: some View {
        @Bindable var fileSearch = session.fileSearch
        return ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                header
                SearchField(text: $fileSearch.query, placeholder: "Search files", focus: $isSearchFocused)
                    .padding(.bottom, DevtailTokens.Spacing.gapSmall)
                if session.fileSearch.isActive {
                    searchResults
                } else if let error = session.fileTree.rootError {
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
        // `initial: true` covers a Cmd+P fired while the processes panel was
        // showing: the request lands before this view mounts, so a plain
        // onChange would never fire. The consumed request is cleared so a
        // later remount doesn't re-steal focus.
        .onChange(of: session.fileSearch.searchFocusRequest, initial: true) { _, request in
            guard request > 0 else { return }
            session.fileSearch.clearFocusRequest()
            // Deferred one runloop tick so the field exists in the AppKit
            // hierarchy before focus is assigned on a fresh mount.
            Task { isSearchFocused = true }
        }
        .onChange(of: session.fileSearch.query) { _, _ in
            selectedResultIndex = 0
        }
        .onKeyPress(.downArrow) { moveSelection(by: 1) }
        .onKeyPress(.upArrow) { moveSelection(by: -1) }
        .onKeyPress(.return) { openSelectedResult() }
        .onKeyPress(.escape) { clearSearch() }
    }

    private var header: some View {
        HStack(spacing: DevtailTokens.Spacing.gapMedium) {
            SectionHeader(title: "Files")
            Spacer()
            iconButton("arrow.clockwise", help: "Sync the file tree") {
                session.fileTree.reloadRoot()
            }
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([session.root])
            } label: {
                finderIcon
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.icon)
            .help("Reveal the project folder in Finder")
        }
    }

    @ViewBuilder private var searchResults: some View {
        let results = session.fileSearch.results
        if results.isEmpty {
            if !session.fileSearch.isSearching {
                Text("No matching files")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .padding(.top, DevtailTokens.Spacing.gapMedium)
            }
        } else {
            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                FileSearchResultRow(
                    result: result,
                    isSelected: index == selectedResultIndex,
                    open: { session.openFile(at: result.path) }
                )
            }
            if results.count == FileSearchWalker.maxResults {
                Text("Showing first \(FileSearchWalker.maxResults) matches")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .padding(.top, DevtailTokens.Spacing.gapSmall)
            }
        }
    }

    private func moveSelection(by delta: Int) -> KeyPress.Result {
        guard session.fileSearch.isActive else { return .ignored }
        let count = session.fileSearch.results.count
        guard count > 0 else { return .ignored }
        selectedResultIndex = min(max(selectedResultIndex + delta, 0), count - 1)
        return .handled
    }

    private func openSelectedResult() -> KeyPress.Result {
        guard session.fileSearch.isActive else { return .ignored }
        let results = session.fileSearch.results
        guard results.indices.contains(selectedResultIndex) else { return .ignored }
        session.openFile(at: results[selectedResultIndex].path)
        return .handled
    }

    private func clearSearch() -> KeyPress.Result {
        guard !session.fileSearch.query.isEmpty else { return .ignored }
        session.fileSearch.query = ""
        selectedResultIndex = 0
        return .handled
    }

    /// The real Finder app icon (LaunchServices), falling back to an SF Symbol
    /// if Finder can't be resolved — same approach as the retired VSCode button.
    @ViewBuilder private var finderIcon: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder") {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: "arrow.up.forward.square")
                .font(.system(size: 15))
                .foregroundStyle(DevtailTokens.Colors.accentPrimary)
        }
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .frame(width: 28, height: 28)
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

/// One flat search result: typed icon, file name, dimmed parent directory
/// relative to the project root. Selection highlight follows the keyboard
/// index in FileTreeColumn.
private struct FileSearchResultRow: View {
    let result: FileSearchResult
    let isSelected: Bool
    let open: () -> Void

    private var icon: FileIconMap.Icon { FileIconMap.icon(for: result.name) }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 4) {
                Image(systemName: icon.symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(icon.color)
                    .frame(width: 14)
                Text(result.name)
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !result.relativeDirectory.isEmpty {
                    Text(result.relativeDirectory)
                        .font(DevtailTokens.Typography.captionSmall)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, DevtailTokens.Spacing.gapSmall)
            .padding(.vertical, DevtailTokens.Spacing.gapTiny)
            .background(
                RoundedRectangle(cornerRadius: DevtailTokens.Radius.sidebarItem)
                    .fill(isSelected ? DevtailTokens.Colors.activeRow : .clear)
            )
        }
        .buttonStyle(.icon)
        .help(result.relativeDirectory.isEmpty ? result.name : "\(result.relativeDirectory)/\(result.name)")
    }
}
