//
//  ClaudePathEncoder.swift
//  Devtail
//
//  Replicates Claude Code's own encoding of a project's absolute path into
//  the directory name it uses under ~/.claude/projects/ for transcript
//  storage: every "/" becomes "-". Verified against real transcripts on
//  disk — see the design doc.
//

import Foundation

enum ClaudePathEncoder {
    static func encode(_ path: String) -> String {
        path.replacingOccurrences(of: "/", with: "-")
    }
}
