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

    private enum ViewerState {
        case loading
        case binary
        case tooLarge(Int)
        case unreadable(String)
        case ready(NSAttributedString, NSColor)
    }

    @State private var state: ViewerState = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .binary:
                placeholder(icon: "doc.zipper", title: "Binary file", detail: "This file can't be displayed.")
            case .tooLarge(let bytes):
                placeholder(icon: "doc.badge.ellipsis", title: "File too large",
                            detail: "\(bytes / (1024 * 1024)) MB exceeds the viewer limit.")
            case .unreadable(let reason):
                placeholder(icon: "exclamationmark.triangle", title: "Can't read file", detail: reason)
            case .ready(let attributed, let background):
                CodeViewerView(attributedText: attributed, backgroundColor: background)
            }
        }
        .task(id: path) {
            state = .loading
            let content = FileContentLoader.load(path: path)
            state = Self.viewerState(for: content)
        }
    }

    private static func viewerState(for content: FileViewerContent) -> ViewerState {
        switch content {
        case .binary:
            return .binary
        case .tooLarge(let bytes):
            return .tooLarge(bytes)
        case .unreadable(let reason):
            return .unreadable(reason)
        case .text(let text, let language, let highlightable):
            let attributed: NSAttributedString
            if highlightable, let highlighted = CodeHighlighter.shared.highlight(text, language: language) {
                attributed = highlighted
            } else {
                attributed = NSAttributedString(string: text, attributes: [
                    .font: NSFont(name: "UbuntuMono-Regular", size: 13) ?? .monospacedSystemFont(ofSize: 13, weight: .regular),
                    .foregroundColor: NSColor.labelColor,
                ])
            }
            let background = highlightable ? CodeHighlighter.shared.backgroundColor : .textBackgroundColor
            return .ready(attributed, background)
        }
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
