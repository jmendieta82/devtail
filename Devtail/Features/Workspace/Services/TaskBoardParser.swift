//
//  TaskBoardParser.swift
//  Devtail
//
//  Pure parse/render for .devtail/tasks.md — the TDD targets, mirroring
//  the GitStatusReader parser pattern. Parsing is total (never fails):
//  anything that is not a known section heading or a task line is kept
//  as raw content so a rewrite preserves it.
//

import Foundation

enum TaskBoardParser {

    /// Matches "- [ ] title" / "- [x] title" (case-insensitive x) and
    /// captures the title. Leading whitespace tolerated.
    private static let taskLinePattern = /^\s*- \[( |x|X)\] (.*)$/

    /// Matches a leading priority token — uppercase A/B/C only — followed
    /// by exactly one space, at the start of the remainder.
    private static let priorityTokenPattern = /^\(([ABC])\) (.*)$/

    /// Matches a leading `YYYY-MM-DD` creation date followed by exactly
    /// one space. Shape only — no calendar validation.
    private static let dateTokenPattern = /^(\d{4}-\d{2}-\d{2}) (.*)$/

    static func parse(_ text: String) -> TaskBoard {
        var preamble: [String] = []
        var sections: [TaskState: [TaskBoardLine]] = [:]
        var currentSection: TaskState?

        // split(omittingEmptySubsequences: false) keeps blank lines, but a
        // trailing newline would add one phantom empty line — drop it.
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.last == "" { lines.removeLast() }

        for line in lines {
            if let state = TaskState.allCases.first(where: { $0.heading == line.trimmingCharacters(in: .whitespaces) }) {
                currentSection = state
                sections[state, default: []] = sections[state] ?? []
                continue
            }
            guard let section = currentSection else {
                preamble.append(line)
                continue
            }
            if let match = line.firstMatch(of: taskLinePattern) {
                var remainder = String(match.2)
                var priority: TaskPriority?
                var createdDate: String?
                if let priorityMatch = remainder.firstMatch(of: priorityTokenPattern) {
                    priority = TaskPriority(rawValue: String(priorityMatch.1))
                    remainder = String(priorityMatch.2)
                }
                if let dateMatch = remainder.firstMatch(of: dateTokenPattern) {
                    createdDate = String(dateMatch.1)
                    remainder = String(dateMatch.2)
                }
                sections[section, default: []].append(
                    .task(TaskItem(title: remainder, state: section, priority: priority, createdDate: createdDate))
                )
            } else {
                sections[section, default: []].append(.raw(line))
            }
        }
        return TaskBoard(preamble: preamble, sections: sections)
    }

    /// Renders the canonical file: preamble verbatim, then the three
    /// sections in fixed Doing/Pending/Done order, checkboxes normalized
    /// to the section (x only in Done). Ends with a single newline.
    static func render(_ board: TaskBoard) -> String {
        var lines: [String] = board.preamble
        for state in TaskState.allCases {
            lines.append(state.heading)
            let sectionLines = board.sections[state] ?? []
            for line in sectionLines {
                switch line {
                case .task(let item):
                    let box = state == .done ? "x" : " "
                    var prefix = ""
                    if let priority = item.priority { prefix += "\(priority.token) " }
                    if let createdDate = item.createdDate { prefix += "\(createdDate) " }
                    lines.append("- [\(box)] \(prefix)\(item.title)")
                case .raw(let raw):
                    lines.append(raw)
                }
            }
            // Blank separator after a section unless its content already
            // ends with one — keeps the file airy without doubling blanks.
            if lines.last != "" { lines.append("") }
        }
        // Single trailing newline, no trailing blank line.
        if lines.last == "" { lines.removeLast() }
        return lines.joined(separator: "\n") + "\n"
    }
}
