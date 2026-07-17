//
//  ClaudePathEncoderTests.swift
//  DevtailTests
//
//  TDD for ClaudePathEncoder: replicates Claude Code's own encoding of a
//  project's absolute path into the directory name it uses under
//  ~/.claude/projects/ for transcript storage — every "/" becomes "-".
//

import Testing
@testable import Devtail

struct ClaudePathEncoderTests {
    @Test func encodesNormalAbsolutePath() {
        let encoded = ClaudePathEncoder.encode("/Volumes/Datos/Frelancer/DarSoluciones")
        #expect(encoded == "-Volumes-Datos-Frelancer-DarSoluciones")
    }

    @Test func encodesPathWithSpaces() {
        let encoded = ClaudePathEncoder.encode("/Users/jamodev/My Projects/app")
        #expect(encoded == "-Users-jamodev-My Projects-app")
    }

    @Test func encodesPathWithTrailingSlash() {
        let encoded = ClaudePathEncoder.encode("/Users/jamodev/app/")
        #expect(encoded == "-Users-jamodev-app-")
    }
}
