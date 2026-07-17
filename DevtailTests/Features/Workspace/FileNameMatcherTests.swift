import Foundation
import Testing
@testable import Devtail

@MainActor
struct FileNameMatcherTests {
    private let matcher = FileNameMatcher()

    @Test func emptyQueryNormalizesToNil() {
        #expect(matcher.normalizedQuery(from: "") == nil)
    }

    @Test func whitespaceOnlyQueryNormalizesToNil() {
        #expect(matcher.normalizedQuery(from: "  \n\t ") == nil)
    }

    @Test func normalizationTrimsAndLowercases() {
        #expect(matcher.normalizedQuery(from: "  ReadMe ") == "readme")
    }

    @Test func matchIsCaseInsensitive() {
        #expect(matcher.matches(name: "README.md", normalizedQuery: "readme"))
    }

    @Test func matchIsSubstringAnywhereInName() {
        #expect(matcher.matches(name: "FileTreeStore.swift", normalizedQuery: "tree"))
        #expect(matcher.matches(name: "FileTreeStore.swift", normalizedQuery: ".swift"))
    }

    @Test func nonMatchingNameIsRejected() {
        #expect(!matcher.matches(name: "FileTreeStore.swift", normalizedQuery: "walker"))
    }
}
