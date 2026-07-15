import Testing
@testable import Devtail

struct CodeLanguageMapTests {
    @Test func knownExtensions() {
        #expect(CodeLanguageMap.language(forExtension: "swift") == "swift")
        #expect(CodeLanguageMap.language(forExtension: "ts") == "typescript")
        #expect(CodeLanguageMap.language(forExtension: "yml") == "yaml")
        #expect(CodeLanguageMap.language(forExtension: "html") == "xml")
    }
    @Test func caseInsensitive() {
        #expect(CodeLanguageMap.language(forExtension: "SWIFT") == "swift")
    }
    @Test func unknownReturnsNilForAutoDetect() {
        #expect(CodeLanguageMap.language(forExtension: "xyzzy") == nil)
    }
}
