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

    // MARK: - parseBranchList

    @Test("parseBranchList returns one branch name per line, in order")
    func parseBranchListMultiple() {
        #expect(GitStatusReader.parseBranchList("main\ndev\n") == ["main", "dev"])
    }

    @Test("parseBranchList returns empty for empty output")
    func parseBranchListEmpty() {
        #expect(GitStatusReader.parseBranchList("") == [])
    }

    @Test("parseBranchList ignores blank lines and trims whitespace")
    func parseBranchListIgnoresBlankLines() {
        #expect(GitStatusReader.parseBranchList("main\n\n  dev \n") == ["main", "dev"])
    }

    // MARK: - parseLastCommit

    @Test("parseLastCommit parses subject and unix timestamp")
    func parseLastCommitValid() {
        let result = GitStatusReader.parseLastCommit("fix: teardown race\t1752854400\n")
        #expect(result?.subject == "fix: teardown race")
        #expect(result?.date == Date(timeIntervalSince1970: 1_752_854_400))
    }

    @Test("parseLastCommit keeps tabs inside the subject (splits on the last tab)")
    func parseLastCommitSubjectWithTab() {
        let result = GitStatusReader.parseLastCommit("subject\twith tab\t1752854400")
        #expect(result?.subject == "subject\twith tab")
        #expect(result?.date == Date(timeIntervalSince1970: 1_752_854_400))
    }

    @Test("parseLastCommit returns nil for empty output")
    func parseLastCommitEmpty() {
        #expect(GitStatusReader.parseLastCommit("") == nil)
    }

    @Test("parseLastCommit returns nil when the tab separator is missing")
    func parseLastCommitMissingTab() {
        #expect(GitStatusReader.parseLastCommit("just a subject") == nil)
    }

    @Test("parseLastCommit returns nil for a non-numeric timestamp")
    func parseLastCommitBadTimestamp() {
        #expect(GitStatusReader.parseLastCommit("subject\tnot-a-number") == nil)
    }
}
