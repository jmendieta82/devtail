//
//  ShellCommand.swift
//  Devtail
//
//  Pure helpers for building the PTY spawn invocation. Commands run through
//  the user's interactive LOGIN shell so PATH additions from ~/.zshrc
//  (Homebrew, nvm, zoxide) are present even when the app is opened from
//  Finder — a plain `-l` shell does not source ~/.zshrc.
//

import Foundation

enum ShellCommand {
    /// The user's shell, from $SHELL, defaulting to zsh (macOS default).
    static func userShell(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        let shell = environment["SHELL"] ?? ""
        return shell.isEmpty ? "/bin/zsh" : shell
    }

    /// execv-style invocation: `[shell, "-ilc", command]`, or `[shell, "-il"]`
    /// for a plain interactive session. Args are passed as an array — the
    /// shell receives `command` verbatim, no extra quoting layer.
    static func loginShellInvocation(command: String?, shell: String) -> [String] {
        let trimmed = command?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return [shell, "-il"] }
        return [shell, "-ilc", trimmed]
    }

    /// Environment for a PTY child: the app's FULL inherited environment
    /// (HOME, PATH, SHELL, TMPDIR, everything — like real terminal emulators
    /// do) overlaid with terminal identity vars. SwiftTerm's own env builder
    /// drops PATH deliberately and starves login shells; we don't use it.
    static func sessionEnvironment(
        base: [String: String] = ProcessInfo.processInfo.environment,
        termName: String = "xterm-256color"
    ) -> [String] {
        var merged = base
        merged["TERM"] = termName
        merged["COLORTERM"] = "truecolor"
        if merged["LANG"] == nil { merged["LANG"] = "en_US.UTF-8" }
        return merged.map { "\($0.key)=\($0.value)" }.sorted()
    }
}
