import AppKit
import Highlighter

/// MainActor-confined wrapper around HighlighterSwift (JSContext is not Sendable).
/// Cost per file is bounded by FileContentLoader's highlight guardrails.
@MainActor
final class CodeHighlighter {
    static let shared = CodeHighlighter()

    private var engine: Highlighter?
    private var isSetUp = false

    private init() {}

    var backgroundColor: NSColor {
        setUpIfNeeded()
        return engine?.theme?.themeBackgroundColour ?? .textBackgroundColor
    }

    func highlight(_ code: String, language: String?) -> NSAttributedString? {
        setUpIfNeeded()
        return engine?.highlight(code, as: language, doFastRender: true)
    }

    private func setUpIfNeeded() {
        guard !isSetUp else { return }
        isSetUp = true
        engine = Highlighter()
        engine?.setTheme("material-palenight", withFont: "UbuntuMono-Regular", ofSize: 13)
    }
}
