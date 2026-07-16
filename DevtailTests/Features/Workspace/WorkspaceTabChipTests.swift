import Testing
@testable import Devtail

struct WorkspaceTabChipTests {
    @Test func shortTitleIsUntouched() {
        #expect(WorkspaceTabChip.truncated("agent") == "agent")
    }

    @Test func boundaryTitleIsUntouched() {
        let exactly28 = String(repeating: "a", count: 28)
        #expect(WorkspaceTabChip.truncated(exactly28) == exactly28)
    }

    @Test func longTitleIsMiddleTruncated() {
        let name = "2026-06-22-frontend-extraccion-contratos.md"
        let result = WorkspaceTabChip.truncated(name)
        #expect(result == "2026-06-22-fro…-contratos.md")
        #expect(result.hasSuffix(".md"))
        #expect(result.count == 28)
    }
}
