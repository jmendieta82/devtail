//
//  TaskBoardParserTests.swift
//  DevtailTests
//
//  TDD for the pure task-board parser/renderer and the TaskBoard mutations.
//  The file contract: section headings are the source of truth for state,
//  unknown lines survive a round-trip verbatim, render normalizes
//  checkboxes and always writes sections in Doing/Pending/Done order.
//

import Testing
import Foundation
@testable import Devtail

@Suite("TaskBoardParser")
struct TaskBoardParserTests {

    // MARK: - parse

    @Test("parse reads tasks into their sections")
    func parseBasicSections() {
        let text = """
        # Tasks

        ## Doing
        - [ ] refactor auth

        ## Pending
        - [ ] review pagination
        - [ ] fix logging

        ## Done
        - [x] branch card
        """
        let board = TaskBoardParser.parse(text)
        #expect(board.tasks(in: .doing).map(\.title) == ["refactor auth"])
        #expect(board.tasks(in: .pending).map(\.title) == ["review pagination", "fix logging"])
        #expect(board.tasks(in: .done).map(\.title) == ["branch card"])
    }

    @Test("parse keeps preamble lines before the first section")
    func parsePreamble() {
        let board = TaskBoardParser.parse("# Tasks\nsome note\n\n## Pending\n- [ ] a\n")
        #expect(board.preamble == ["# Tasks", "some note", ""])
    }

    @Test("parse assigns state from the section, ignoring the checkbox")
    func parseSectionBeatsCheckbox() {
        let board = TaskBoardParser.parse("## Pending\n- [x] agent marked this done in place\n")
        let tasks = board.tasks(in: .pending)
        #expect(tasks.count == 1)
        #expect(tasks[0].state == .pending)
        #expect(board.tasks(in: .done).isEmpty)
    }

    @Test("parse accepts uppercase X in the checkbox")
    func parseUppercaseCheckbox() {
        let board = TaskBoardParser.parse("## Done\n- [X] shipped\n")
        #expect(board.tasks(in: .done).map(\.title) == ["shipped"])
    }

    @Test("parse preserves non-task lines inside a section")
    func parseRawLinesInsideSection() {
        let text = "## Pending\nnote from the agent\n- [ ] a\n\n"
        let board = TaskBoardParser.parse(text)
        let lines = board.sections[.pending] ?? []
        #expect(lines.count == 3)
        #expect(lines[0] == .raw("note from the agent"))
        #expect(lines[2] == .raw(""))
    }

    @Test("parse of empty text yields an empty board with no preamble")
    func parseEmpty() {
        let board = TaskBoardParser.parse("")
        #expect(board.preamble.isEmpty)
        for state in TaskState.allCases {
            #expect((board.sections[state] ?? []).isEmpty)
        }
    }

    // MARK: - render

    @Test("render writes sections in Doing, Pending, Done order")
    func renderSectionOrder() {
        let board = TaskBoardParser.parse("## Done\n- [x] z\n\n## Doing\n- [ ] a\n")
        let output = TaskBoardParser.render(board)
        let doingIndex = output.range(of: "## Doing")!.lowerBound
        let doneIndex = output.range(of: "## Done")!.lowerBound
        #expect(doingIndex < doneIndex)
    }

    @Test("render normalizes checkboxes to the section")
    func renderNormalizesCheckboxes() {
        let board = TaskBoardParser.parse("## Pending\n- [x] wrongly checked\n## Done\n- [ ] wrongly unchecked\n")
        let output = TaskBoardParser.render(board)
        #expect(output.contains("- [ ] wrongly checked"))
        #expect(output.contains("- [x] wrongly unchecked"))
    }

    @Test("parse then render round-trips unknown content verbatim")
    func roundTripPreservesUnknownLines() {
        let text = """
        # Tasks
        intro note

        ## Doing
        context line
        - [ ] a

        ## Pending

        ## Done
        """
        let rendered = TaskBoardParser.render(TaskBoardParser.parse(text))
        #expect(rendered.contains("intro note"))
        #expect(rendered.contains("context line"))
    }

    @Test("render of the empty template matches the documented shape")
    func renderEmptyTemplate() {
        let output = TaskBoardParser.render(.empty)
        #expect(output == "# Tasks\n\n## Doing\n\n## Pending\n\n## Done\n")
    }

    // MARK: - mutations

    @Test("add appends to Pending")
    func addAppendsToPending() {
        var board = TaskBoard.empty
        board.add(title: "new work")
        #expect(board.tasks(in: .pending).map(\.title) == ["new work"])
    }

    @Test("add to an explicit state lands there, leaving Pending untouched")
    func addToExplicitState() {
        var board = TaskBoard.empty
        board.add(title: "x", to: .doing)
        #expect(board.tasks(in: .doing).map(\.title) == ["x"])
        #expect(board.tasks(in: .pending).isEmpty)
    }

    @Test("move relocates a task to the end of the target section")
    func moveRelocates() {
        var board = TaskBoard.empty
        board.add(title: "a")
        board.add(title: "b")
        let id = board.tasks(in: .pending)[0].id
        board.move(id: id, to: .doing)
        #expect(board.tasks(in: .pending).map(\.title) == ["b"])
        #expect(board.tasks(in: .doing).map(\.title) == ["a"])
        #expect(board.tasks(in: .doing)[0].state == .doing)
    }

    @Test("move with an unknown id is a no-op")
    func moveUnknownIdNoop() {
        var board = TaskBoard.empty
        board.add(title: "a")
        board.move(id: UUID(), to: .done)
        #expect(board.tasks(in: .pending).map(\.title) == ["a"])
        #expect(board.tasks(in: .done).isEmpty)
    }

    @Test("rename updates the title in place, keeping position and state")
    func renameUpdatesInPlace() {
        var board = TaskBoardParser.parse("## Doing\n- [ ] before\n- [ ] neighbor\n")
        let id = board.tasks(in: .doing)[0].id
        board.rename(id: id, to: "after")
        #expect(board.tasks(in: .doing).map(\.title) == ["after", "neighbor"])
        #expect(board.tasks(in: .doing)[0].id == id)
    }

    @Test("rename with an unknown id is a no-op")
    func renameUnknownIdNoop() {
        var board = TaskBoard.empty
        board.add(title: "a")
        board.rename(id: UUID(), to: "b")
        #expect(board.tasks(in: .pending).map(\.title) == ["a"])
    }

    @Test("setPriority sets then clears in place, keeping position and id")
    func setPriorityInPlace() {
        var board = TaskBoardParser.parse("## Doing\n- [ ] a\n- [ ] b\n")
        let id = board.tasks(in: .doing)[0].id
        board.setPriority(id: id, to: .high)
        #expect(board.tasks(in: .doing)[0].priority == .high)
        #expect(board.tasks(in: .doing)[0].id == id)
        #expect(board.tasks(in: .doing).map(\.title) == ["a", "b"])

        board.setPriority(id: id, to: nil)
        #expect(board.tasks(in: .doing)[0].priority == nil)
        #expect(board.tasks(in: .doing)[0].id == id)
    }

    @Test("removeDoneTasks returns done tasks and clears only task lines from Done")
    func removeDoneTasks() {
        var board = TaskBoardParser.parse("## Done\nkept note\n- [x] shipped\n")
        let removed = board.removeDoneTasks()
        #expect(removed.map(\.title) == ["shipped"])
        #expect(board.tasks(in: .done).isEmpty)
        #expect(board.sections[.done] == [.raw("kept note")])
    }

    // MARK: - priority + creation date

    @Test("parse reads both priority and creation date, leaving title clean")
    func parsePriorityAndDate() {
        let board = TaskBoardParser.parse("## Pending\n- [ ] (A) 2026-07-18 title\n")
        let task = board.tasks(in: .pending)[0]
        #expect(task.title == "title")
        #expect(task.priority == .high)
        #expect(task.createdDate == "2026-07-18")
    }

    @Test("parse reads a priority token with no date")
    func parsePriorityOnly() {
        let board = TaskBoardParser.parse("## Pending\n- [ ] (B) title\n")
        let task = board.tasks(in: .pending)[0]
        #expect(task.title == "title")
        #expect(task.priority == .medium)
        #expect(task.createdDate == nil)
    }

    @Test("parse reads a creation date with no priority")
    func parseDateOnly() {
        let board = TaskBoardParser.parse("## Pending\n- [ ] 2026-07-18 title\n")
        let task = board.tasks(in: .pending)[0]
        #expect(task.title == "title")
        #expect(task.priority == nil)
        #expect(task.createdDate == "2026-07-18")
    }

    @Test("parse leaves a non-priority parenthetical in the title untouched")
    func parseParenthesesInTitleNotPriority() {
        let boardD = TaskBoardParser.parse("## Pending\n- [ ] (D) title\n")
        #expect(boardD.tasks(in: .pending)[0].title == "(D) title")
        #expect(boardD.tasks(in: .pending)[0].priority == nil)

        let boardLower = TaskBoardParser.parse("## Pending\n- [ ] (a) title\n")
        #expect(boardLower.tasks(in: .pending)[0].title == "(a) title")
        #expect(boardLower.tasks(in: .pending)[0].priority == nil)
    }

    @Test("render writes priority and date tokens back verbatim")
    func renderWritesTokensBack() {
        let text = "## Pending\n- [ ] (B) 2026-07-18 x\n"
        let rendered = TaskBoardParser.render(TaskBoardParser.parse(text))
        #expect(rendered.contains("- [ ] (B) 2026-07-18 x"))
    }

    @Test("render omits priority/date tokens when absent")
    func renderOmitsAbsentTokens() {
        let text = "## Pending\n- [ ] plain title\n"
        let rendered = TaskBoardParser.render(TaskBoardParser.parse(text))
        #expect(rendered.contains("- [ ] plain title"))
    }
}
