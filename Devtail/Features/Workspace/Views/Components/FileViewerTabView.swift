//
//  FileViewerTabView.swift
//  Devtail
//
//  Center-column tab content for an open file. Read-only for everything
//  except the .env family (see EnvFileDetector), which gets an editable
//  surface (EnvFileEditorView) instead — the first write path in the
//  viewer. Loads the file via FileContentLoader's guardrails and renders
//  CodeViewerView, or a placeholder for binary/too-large/unreadable files.
//

import SwiftUI

/// Center-column tab content for an open file: read-only, except .env
/// family files which become editable.
struct FileViewerTabView: View {
    let path: String
    let session: WorkspaceSession

    private enum ViewerMode: String, CaseIterable, Identifiable {
        case preview = "Preview"
        case source = "Source"

        var id: String { rawValue }
    }

    private enum ViewerState {
        case loading
        case binary
        case tooLarge(Int)
        case unreadable(String)
        /// `markdownBlocks` is parsed once when the file loads (not on every
        /// body evaluation) and reused both for the fallback decision and for
        /// `MarkdownDocumentView` itself.
        case ready(NSAttributedString, NSColor, rawText: String, markdownBlocks: [MarkdownBlock])
    }

    @State private var state: ViewerState = .loading
    @State private var mode: ViewerMode = .preview
    @State private var loadedModificationDate: Date?

    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown"]

    private var isMarkdown: Bool {
        Self.markdownExtensions.contains(URL(fileURLWithPath: path).pathExtension.lowercased())
    }

    private var isEnvFile: Bool {
        EnvFileDetector.isEnvFile(path: path)
    }

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
            case .ready(let attributed, let background, let rawText, let markdownBlocks):
                if isEnvFile {
                    EnvFileEditorView(
                        path: path,
                        loadedText: rawText,
                        loadedModificationDate: loadedModificationDate,
                        session: session
                    )
                } else if isMarkdown {
                    VStack(spacing: 0) {
                        HStack {
                            Spacer()
                            Picker("View", selection: $mode) {
                                ForEach(ViewerMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 160)
                        }
                        .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
                        .padding(.vertical, DevtailTokens.Spacing.gapSmall)

                        switch mode {
                        case .preview:
                            if Self.shouldFallBackToSource(rawText: rawText, blocks: markdownBlocks) {
                                CodeViewerView(attributedText: attributed, backgroundColor: background)
                            } else {
                                MarkdownDocumentView(blocks: markdownBlocks)
                            }
                        case .source:
                            CodeViewerView(attributedText: attributed, backgroundColor: background)
                        }
                    }
                } else {
                    CodeViewerView(attributedText: attributed, backgroundColor: background)
                }
            }
        }
        .task(id: path) {
            state = .loading
            let content = FileContentLoader.load(path: path)
            loadedModificationDate = EnvFileSaver.modificationDate(at: path)
            state = Self.viewerState(for: content, isMarkdown: isMarkdown)
        }
    }

    /// Decides whether Preview mode should fall back to rendering the raw
    /// Source view instead of a blank markdown pane. `AttributedString(markdown:)`
    /// can throw on malformed input, in which case `MarkdownBlockParser.parse`
    /// returns `[]`. If the file actually has content, showing nothing would
    /// silently hide it — falling back to Source guarantees the user always
    /// sees something.
    static func shouldFallBackToSource(rawText: String, blocks: [MarkdownBlock]) -> Bool {
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return blocks.isEmpty
    }

    private static func viewerState(for content: FileViewerContent, isMarkdown: Bool) -> ViewerState {
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
            let markdownBlocks = isMarkdown ? MarkdownBlockParser.parse(text) : []
            return .ready(attributed, background, rawText: text, markdownBlocks: markdownBlocks)
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
