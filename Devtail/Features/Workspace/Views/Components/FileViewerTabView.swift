//
//  FileViewerTabView.swift
//  Devtail
//
//  Center-column tab content for an open file (read-only). Loads the file
//  via FileContentLoader's guardrails and renders CodeViewerView, or a
//  placeholder for binary/too-large/unreadable files.
//

import SwiftUI

/// Center-column tab content for an open file (read-only).
struct FileViewerTabView: View {
    let path: String

    @State private var content: FileViewerContent?

    var body: some View {
        Group {
            switch content {
            case nil:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .binary:
                placeholder(icon: "doc.zipper", title: "Binary file", detail: "This file can't be displayed.")
            case .tooLarge(let bytes):
                placeholder(icon: "doc.badge.ellipsis", title: "File too large",
                            detail: "\(bytes / (1024 * 1024)) MB exceeds the viewer limit.")
            case .unreadable(let reason):
                placeholder(icon: "exclamationmark.triangle", title: "Can't read file", detail: reason)
            case .text(let text, let language, let highlightable):
                viewer(text: text, language: language, highlightable: highlightable)
            }
        }
        .task(id: path) { content = FileContentLoader.load(path: path) }
    }

    private func viewer(text: String, language: String?, highlightable: Bool) -> some View {
        let attributed: NSAttributedString
        if highlightable, let highlighted = CodeHighlighter.shared.highlight(text, language: language) {
            attributed = highlighted
        } else {
            attributed = NSAttributedString(string: text, attributes: [
                .font: NSFont(name: "UbuntuMono-Regular", size: 13) ?? .monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.labelColor,
            ])
        }
        return CodeViewerView(
            attributedText: attributed,
            backgroundColor: highlightable ? CodeHighlighter.shared.backgroundColor : .textBackgroundColor
        )
    }

    private func placeholder(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    FileViewerTabView(path: #file)
        .frame(width: 640, height: 480)
}
