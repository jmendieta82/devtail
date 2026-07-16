//
//  MarkdownDocumentView.swift
//  Devtail
//
//  Formatted rendering of a markdown document, built from MarkdownBlockParser
//  output. Used by FileViewerTabView as the "Preview" side of the
//  Preview/Source toggle for .md files.
//

import SwiftUI

/// Renders a markdown string as formatted content (headings, inline styles,
/// lists, code blocks, block quotes, thematic breaks).
struct MarkdownDocumentView: View {
    /// Parsed once in `init` and stored — `text` is immutable for the
    /// lifetime of a view instance (a new file means a new `FileViewerTabView`
    /// and thus a new `MarkdownDocumentView`), so re-parsing on every body
    /// evaluation was wasted work. See `Devtail/Features/Workspace/Services/MarkdownBlockParser.swift`.
    let blocks: [MarkdownBlock]

    /// Cap on the document's readable width, centered in the available
    /// space — same pattern as WorkspaceSettingsTabView.contentMaxWidth.
    private static let contentMaxWidth: CGFloat = 760

    init(text: String) {
        self.blocks = MarkdownBlockParser.parse(text)
    }

    init(blocks: [MarkdownBlock]) {
        self.blocks = blocks
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapLarge) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(for: block)
                }
            }
            .frame(maxWidth: Self.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(DevtailTokens.Spacing.dashboardPadding)
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let attributedText):
            Text(attributedText)
                .font(headingFont(for: level))
                .padding(.top, level == 1 ? DevtailTokens.Spacing.gapSection : DevtailTokens.Spacing.gapDefault)

        case .paragraph(let attributedText):
            Text(attributedText)
                .font(DevtailTokens.Typography.body)
                .lineSpacing(4)

        case .codeBlock(_, let code):
            Text(code)
                .font(DevtailTokens.Typography.mono)
                .foregroundStyle(DevtailTokens.Colors.textPrimary)
                .padding(DevtailTokens.Spacing.gapMedium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DevtailTokens.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: DevtailTokens.Radius.card))

        case .listItem(let ordinal, let indent, let attributedText):
            HStack(alignment: .top, spacing: DevtailTokens.Spacing.gapSmall) {
                Text(ordinal.map { "\($0)." } ?? "\u{2022}")
                    .font(DevtailTokens.Typography.body)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
                    .frame(minWidth: 20, alignment: .trailing)
                Text(attributedText)
                    .font(DevtailTokens.Typography.body)
                    .lineSpacing(4)
            }
            .padding(.leading, CGFloat(indent) * DevtailTokens.Spacing.gapXLarge)

        case .blockQuote(let attributedText):
            HStack(spacing: DevtailTokens.Spacing.gapMedium) {
                Rectangle()
                    .fill(DevtailTokens.Colors.borderPrimary)
                    .frame(width: DevtailTokens.BorderWidth.accentStrip)
                Text(attributedText)
                    .font(DevtailTokens.Typography.body)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
                    .lineSpacing(4)
            }

        case .thematicBreak:
            Divider()
        }
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: return .system(size: 24, weight: .semibold)
        case 2: return .system(size: 20, weight: .semibold)
        case 3: return .system(size: 17, weight: .semibold)
        default: return .system(size: 15, weight: .semibold)
        }
    }
}

#Preview {
    MarkdownDocumentView(text: """
    # Devtail Markdown Preview

    This is a **bold** statement and this is *italic*.

    ```swift
    let greeting = "Hello, Devtail"
    print(greeting)
    ```

    - First bullet
    - Second bullet

    1. First step
    2. Second step

    > A quoted remark.

    ---

    Final paragraph.
    """)
    .frame(width: 640, height: 600)
}
