//
//  GitStatusReaderTests.swift
//  DevtailTests
//
//  Tests the pure static parsers extracted from GitStatusReader. The
//  Process-running side (GitStatusReader.status(in:)) is not exercised
//  here — it shells out to the real `git` binary and is documented as a
//  best-effort manual check instead (see the design doc).
//

import Testing
import Foundation
@testable import Devtail

@Suite("GitStatusReader parsers")
struct GitStatusReaderTests {

    // MARK: - parseAheadBehind

    @Test("parseAheadBehind parses a well-formed left-right count line")
    func parseAheadBehindValid() {
        let result = GitStatusReader.parseAheadBehind("2\t5")
        #expect(result?.behind == 2)
        #expect(result?.ahead == 5)
    }

    @Test("parseAheadBehind trims trailing newline")
    func parseAheadBehindTrimsNewline() {
        let result = GitStatusReader.parseAheadBehind("0\t3\n")
        #expect(result?.behind == 0)
        #expect(result?.ahead == 3)
    }

    @Test("parseAheadBehind returns nil for malformed output")
    func parseAheadBehindMalformed() {
        #expect(GitStatusReader.parseAheadBehind("garbage") == nil)
    }

    @Test("parseAheadBehind returns nil for empty output")
    func parseAheadBehindEmpty() {
        #expect(GitStatusReader.parseAheadBehind("") == nil)
    }

    // MARK: - parsePorcelain

    @Test("parsePorcelain returns clean/zero for empty output")
    func parsePorcelainEmpty() {
        let result = GitStatusReader.parsePorcelain("")
        #expect(result.isDirty == false)
        #expect(result.count == 0)
    }

    @Test("parsePorcelain counts changed files and marks dirty")
    func parsePorcelainDirty() {
        let result = GitStatusReader.parsePorcelain(" M a.txt\n?? b.txt\n")
        #expect(result.isDirty == true)
        #expect(result.count == 2)
    }

    @Test("parsePorcelain ignores blank lines")
    func parsePorcelainIgnoresBlankLines() {
        let result = GitStatusReader.parsePorcelain(" M a.txt\n\n")
        #expect(result.isDirty == true)
        #expect(result.count == 1)
    }

    // MARK: - parseBranchCount

    @Test("parseBranchCount counts one branch per line")
    func parseBranchCountMultiple() {
        #expect(GitStatusReader.parseBranchCount("main\ndev\n") == 2)
    }

    @Test("parseBranchCount returns zero for empty output")
    func parseBranchCountEmpty() {
        #expect(GitStatusReader.parseBranchCount("") == 0)
    }

    @Test("parseBranchCount ignores blank lines")
    func parseBranchCountIgnoresBlankLines() {
        #expect(GitStatusReader.parseBranchCount("main\n\ndev\n") == 2)
    }
}
