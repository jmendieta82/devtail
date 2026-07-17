//
//  TokenCountFormatterTests.swift
//  DevtailTests
//
//  TDD for TokenCountFormatter: compact display of large token counts in
//  the Claude card, e.g. 1_234_567 -> "1.2M", 340_000 -> "340k".
//

import Testing
@testable import Devtail

struct TokenCountFormatterTests {
    @Test func formatsCountsBelowOneThousandAsIs() {
        #expect(TokenCountFormatter.format(0) == "0")
        #expect(TokenCountFormatter.format(999) == "999")
    }

    @Test func formatsThousandsWithKSuffix() {
        #expect(TokenCountFormatter.format(340_000) == "340k")
        #expect(TokenCountFormatter.format(1_000) == "1k")
    }

    @Test func formatsMillionsWithMSuffixAndOneDecimal() {
        #expect(TokenCountFormatter.format(1_234_567) == "1.2M")
        #expect(TokenCountFormatter.format(2_000_000) == "2.0M")
    }
}
