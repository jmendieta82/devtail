import Foundation
import Testing
@testable import Devtail

struct FileViewerTabViewTests {
    @Test func emptyTextNeverFallsBack() {
        #expect(FileViewerTabView.shouldFallBackToSource(rawText: "", blocks: []) == false)
    }

    @Test func blankTextNeverFallsBack() {
        #expect(FileViewerTabView.shouldFallBackToSource(rawText: "   \n\t  ", blocks: []) == false)
    }

    @Test func nonEmptyTextWithNoBlocksFallsBack() {
        let text = "# Title\nSome content that failed to parse."
        #expect(FileViewerTabView.shouldFallBackToSource(rawText: text, blocks: []) == true)
    }

    @Test func nonEmptyTextWithBlocksDoesNotFallBack() {
        let text = "# Title"
        let blocks = MarkdownBlockParser.parse(text)
        #expect(FileViewerTabView.shouldFallBackToSource(rawText: text, blocks: blocks) == false)
    }
}
