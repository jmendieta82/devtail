//
//  CodeViewerView.swift
//  Devtail
//
//  Read-only code surface: NSTextView + line-number ruler. Used by
//  FileViewerTabView to render highlighted (or plain) file contents.
//

import AppKit
import SwiftUI

/// Read-only code surface: NSTextView + line-number ruler.
struct CodeViewerView: NSViewRepresentable {
    let attributedText: NSAttributedString
    let backgroundColor: NSColor

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasVerticalRuler = true
        scrollView.verticalRulerView = LineNumberRulerView(textView: textView)
        scrollView.rulersVisible = true
        scrollView.drawsBackground = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.textStorage?.setAttributedString(attributedText)
        textView.backgroundColor = backgroundColor
        scrollView.backgroundColor = backgroundColor
        (scrollView.verticalRulerView as? LineNumberRulerView)?.needsDisplay = true
    }
}

/// Classic macOS line-number gutter (NSRulerView over the scroll view).
///
/// Deliberately accesses `textView.layoutManager`, which forces the text view
/// into TextKit 1 compatibility mode. That's acceptable here: this is a
/// read-only viewer with no TextKit 2 features in use, and TextKit 1's
/// glyph/line-fragment APIs are what make a classic gutter straightforward.
final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?

    private static let font = NSFont(name: "UbuntuMono-Regular", size: 11)
        ?? .monospacedSystemFont(ofSize: 11, weight: .regular)
    private static let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.tertiaryLabelColor,
    ]

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 44
        NotificationCenter.default.addObserver(
            self, selector: #selector(textDidChange),
            name: NSText.didChangeNotification, object: textView
        )
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func textDidChange() { needsDisplay = true }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        let inset = textView.textContainerInset
        let visibleGlyphs = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: container)
        let text = textView.string as NSString

        // Count newlines up to the first visible glyph's character index to
        // establish the starting line number for this scroll position.
        let firstVisibleCharIndex = visibleGlyphs.location < layoutManager.numberOfGlyphs
            ? layoutManager.characterIndexForGlyph(at: visibleGlyphs.location)
            : text.length
        var lineNumber = text.substring(to: firstVisibleCharIndex)
            .components(separatedBy: "\n").count

        var glyphIndex = visibleGlyphs.location
        while glyphIndex < NSMaxRange(visibleGlyphs) {
            var lineGlyphRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let charRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
            let isLineStart = charRange.location == 0
                || text.character(at: charRange.location - 1) == unichar(10)
            if isLineStart {
                let label = "\(lineNumber)" as NSString
                let size = label.size(withAttributes: Self.attributes)

                // lineRect is in the text container's coordinate space, which
                // is offset from the text view's bounds by textContainerInset.
                // Add the inset BEFORE converting to ruler coordinates so the
                // label lines up with the actual glyph row on screen.
                let pointInTextView = NSPoint(x: 0, y: lineRect.minY + inset.height)
                let pointInRuler = convert(pointInTextView, from: textView)

                // Vertically center the label within the line fragment's height.
                let y = pointInRuler.y + (lineRect.height - size.height) / 2
                label.draw(
                    at: NSPoint(x: ruleThickness - size.width - 6, y: y),
                    withAttributes: Self.attributes
                )
                lineNumber += 1
            }
            glyphIndex = NSMaxRange(lineGlyphRange)
        }
    }
}
