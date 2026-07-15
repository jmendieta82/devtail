import Foundation
import Testing
@testable import Devtail

@MainActor
struct CodeHighlighterTests {
    @Test func highlightsSwiftSnippet() {
        let result = CodeHighlighter.shared.highlight("let x = 1", language: "swift")
        #expect(result != nil)
        #expect(result!.length > 0)
    }
    @Test func backgroundColorAvailableAfterUse() {
        _ = CodeHighlighter.shared.highlight("x", language: nil)
        _ = CodeHighlighter.shared.backgroundColor   // no crash, no nil-force
    }
}
