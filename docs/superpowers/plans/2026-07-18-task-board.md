# Project Task Board Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Per-project task board (Doing/Pending/Done) stored in `.devtail/tasks.md`, rendered and edited from a new workspace side panel, writable by both the user and Claude Code agents.

**Architecture:** Pure parser/renderer (`TaskBoardParser`) over a line-preserving `TaskBoard` model, an `@Observable` `TaskBoardStore` composed into `WorkspaceSession` (mirroring `FileTreeStore`/`FileSearchStore`) behind a `TaskBoardFileAccessing` seam, and a `TaskBoardPanel` switched in by a new `SidePanelView.tasks` case.

**Tech Stack:** Swift 5 mode, SwiftUI, Swift Testing (`@Suite`/`@Test`/`#expect`), xcodebuild.

## Global Constraints

- Swift 5 language mode, MainActor default isolation, macOS 26.0 Tahoe minimum (project `CLAUDE.md`).
- Conventional Commits, NEVER any Co-Authored-By/AI attribution.
- No new SPM dependencies.
- Section is the source of truth for task state; render normalizes checkboxes (`- [x]` only in Done).
- Unknown lines (preamble, blanks, non-task lines inside sections) are preserved verbatim and in order on rewrite.
- Full suite command: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS'` run from `/Volumes/Datos/Frelancer/DEVTAIL/Devtail`. Suite is currently 555 tests; never run builds in parallel (check `pgrep -x xcodebuild` first).
- New files must be added to the Xcode project. The pbxproj uses `PBXFileSystemSynchronizedRootGroup` for `Devtail/` and `DevtailTests/` — files written to disk under those roots are picked up automatically; do NOT hand-edit the pbxproj.

---

### Task 1: `TaskBoard` model + `TaskBoardParser` (parse/render/mutations)

**Files:**
- Create: `Devtail/Features/Workspace/Models/TaskBoard.swift`
- Create: `Devtail/Features/Workspace/Services/TaskBoardParser.swift`
- Test: `DevtailTests/Features/Workspace/TaskBoardParserTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces (later tasks rely on these exact names):
  - `enum TaskState: String, CaseIterable, Sendable` — cases `.doing`, `.pending`, `.done`; `var heading: String` returns `"## Doing"` / `"## Pending"` / `"## Done"`; `var displayName: String` returns `"Doing"` / `"Pending"` / `"Done"`.
  - `struct TaskItem: Identifiable, Equatable, Sendable` — `let id: UUID`, `var title: String`, `var state: TaskState`.
  - `enum TaskBoardLine: Equatable, Sendable` — `.task(TaskItem)`, `.raw(String)`.
  - `struct TaskBoard: Equatable, Sendable` — `var preamble: [String]`, `var sections: [TaskState: [TaskBoardLine]]`; `static var empty: TaskBoard` (template shape: preamble `["# Tasks", ""]`, all sections empty); `func tasks(in state: TaskState) -> [TaskItem]`; `mutating func add(title: String)`; `mutating func move(id: UUID, to target: TaskState)`; `mutating func removeDoneTasks() -> [TaskItem]`.
  - `enum TaskBoardParser` — `static func parse(_ text: String) -> TaskBoard`, `static func render(_ board: TaskBoard) -> String`.

- [ ] **Step 1: Write the failing tests**

Create `DevtailTests/Features/Workspace/TaskBoardParserTests.swift`:

```swift
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

    @Test("removeDoneTasks returns done tasks and clears only task lines from Done")
    func removeDoneTasks() {
        var board = TaskBoardParser.parse("## Done\nkept note\n- [x] shipped\n")
        let removed = board.removeDoneTasks()
        #expect(removed.map(\.title) == ["shipped"])
        #expect(board.tasks(in: .done).isEmpty)
        #expect(board.sections[.done] == [.raw("kept note")])
    }
}
```

- [ ] **Step 2: Run the suite to verify it fails to compile**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -20`
Expected: compile FAILURE — `TaskBoard`, `TaskBoardParser`, `TaskState` not found.

- [ ] **Step 3: Implement the model**

Create `Devtail/Features/Workspace/Models/TaskBoard.swift`:

```swift
//
//  TaskBoard.swift
//  Devtail
//
//  In-memory model of a project's .devtail/tasks.md. The SECTION a task
//  sits in is the source of truth for its state — checkboxes are
//  normalized on render. Non-task lines are kept as .raw entries so a
//  rewrite never destroys agent- or hand-written notes.
//

import Foundation

/// The three board states, each backed by a markdown section heading.
enum TaskState: String, CaseIterable, Sendable {
    case doing
    case pending
    case done

    var heading: String {
        switch self {
        case .doing: "## Doing"
        case .pending: "## Pending"
        case .done: "## Done"
        }
    }

    var displayName: String {
        switch self {
        case .doing: "Doing"
        case .pending: "Pending"
        case .done: "Done"
        }
    }
}

/// One task on the board. `id` is assigned at parse time and stable for
/// the lifetime of the loaded board (not persisted to the file).
struct TaskItem: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var state: TaskState

    init(id: UUID = UUID(), title: String, state: TaskState) {
        self.id = id
        self.title = title
        self.state = state
    }
}

/// A line inside a section: either a parsed task or an unknown line kept
/// verbatim for round-trip preservation.
enum TaskBoardLine: Equatable, Sendable {
    case task(TaskItem)
    case raw(String)
}

struct TaskBoard: Equatable, Sendable {
    /// Lines before the first known section heading, preserved verbatim.
    var preamble: [String]
    var sections: [TaskState: [TaskBoardLine]]

    /// The documented on-disk template shape.
    static var empty: TaskBoard {
        TaskBoard(preamble: ["# Tasks", ""], sections: [:])
    }

    func tasks(in state: TaskState) -> [TaskItem] {
        (sections[state] ?? []).compactMap {
            if case .task(let item) = $0 { return item }
            return nil
        }
    }

    /// New tasks always enter Pending, at the end.
    mutating func add(title: String) {
        sections[.pending, default: []].append(
            .task(TaskItem(title: title, state: .pending))
        )
    }

    /// Moves a task to the end of the target section, updating its state.
    /// No-op when the id is not on the board or already in the target.
    mutating func move(id: UUID, to target: TaskState) {
        for state in TaskState.allCases {
            guard var lines = sections[state],
                  let index = lines.firstIndex(where: {
                      if case .task(let item) = $0 { return item.id == id }
                      return false
                  }),
                  case .task(var item) = lines[index] else { continue }
            guard state != target else { return }
            lines.remove(at: index)
            sections[state] = lines
            item.state = target
            sections[target, default: []].append(.task(item))
            return
        }
    }

    /// Removes and returns every task in Done (raw lines stay), for the
    /// archive flow.
    mutating func removeDoneTasks() -> [TaskItem] {
        var removed: [TaskItem] = []
        sections[.done] = (sections[.done] ?? []).filter { line in
            if case .task(let item) = line {
                removed.append(item)
                return false
            }
            return true
        }
        return removed
    }
}
```

- [ ] **Step 4: Implement the parser**

Create `Devtail/Features/Workspace/Services/TaskBoardParser.swift`:

```swift
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
                sections[section, default: []].append(
                    .task(TaskItem(title: String(match.2), state: section))
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
                    lines.append("- [\(box)] \(item.title)")
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
```

- [ ] **Step 5: Run the suite to verify it passes**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **` (555 + 16 = 571 tests). If a parse/render test fails, fix the implementation — the tests are the contract.

- [ ] **Step 6: Commit**

```bash
git add Devtail/Features/Workspace/Models/TaskBoard.swift Devtail/Features/Workspace/Services/TaskBoardParser.swift DevtailTests/Features/Workspace/TaskBoardParserTests.swift
git commit -m "feat(workspace): task board model and markdown parser"
```

---

### Task 2: `TaskBoardFileAccess` seam + `TaskBoardStore` + session wiring

**Files:**
- Create: `Devtail/Features/Workspace/Services/TaskBoardFileAccess.swift`
- Create: `Devtail/Features/Workspace/Stores/TaskBoardStore.swift`
- Modify: `Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift` (session composition ~line 136-137, teardown in `close(projectId:)` near the `fileSearch`/`cancelClaudeInfoRefresh` calls ~line 471)
- Create: `DevtailTests/Features/Workspace/MockTaskBoardFileAccess.swift`
- Test: `DevtailTests/Features/Workspace/TaskBoardStoreTests.swift`

**Interfaces:**
- Consumes: `TaskBoard`, `TaskBoardParser`, `TaskState`, `TaskItem` from Task 1.
- Produces:
  - `protocol TaskBoardFileAccessing: Sendable` — `func read(at url: URL) async -> String?`, `func write(_ text: String, to url: URL) async -> Bool`, `func append(_ text: String, to url: URL) async -> Bool`.
  - `@Observable final class TaskBoardStore` — `init(root: URL, fileAccess: TaskBoardFileAccessing = TaskBoardFileAccess())`; `private(set) var board: TaskBoard?`; `private(set) var fileExists: Bool`; `var boardURL: URL`; `var archiveURL: URL`; `func refresh()`; `func createBoard()`; `func addTask(title: String)`; `func moveTask(id: UUID, to: TaskState)`; `func archiveDone(on date: Date)`; `func cancel()`; `@ObservationIgnored private(set) var ioTask: Task<Void, Never>?` (exposed for test awaiting).
  - `WorkspaceSession.taskBoard: TaskBoardStore` composed in init.

- [ ] **Step 1: Write the failing tests**

Create `DevtailTests/Features/Workspace/MockTaskBoardFileAccess.swift`:

```swift
//
//  MockTaskBoardFileAccess.swift
//  DevtailTests
//
//  In-memory file double for TaskBoardStore tests: a [URL: String] dict
//  plus per-operation failure switches and an optional read delay for
//  cancellation tests.
//

import Foundation
@testable import Devtail

final class MockTaskBoardFileAccess: TaskBoardFileAccessing, @unchecked Sendable {
    var files: [URL: String] = [:]
    var failWrites = false
    var failAppends = false
    var readDelayNanoseconds: UInt64 = 0

    func read(at url: URL) async -> String? {
        if readDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: readDelayNanoseconds)
        }
        return files[url]
    }

    func write(_ text: String, to url: URL) async -> Bool {
        guard !failWrites else { return false }
        files[url] = text
        return true
    }

    func append(_ text: String, to url: URL) async -> Bool {
        guard !failAppends else { return false }
        files[url] = (files[url] ?? "") + text
        return true
    }
}
```

Create `DevtailTests/Features/Workspace/TaskBoardStoreTests.swift`:

```swift
//
//  TaskBoardStoreTests.swift
//  DevtailTests
//
//  TaskBoardStore wiring against the in-memory file double: refresh
//  assign/no-assign semantics, create, write-through mutations, the
//  write-failure re-refresh contract, and archive append-before-remove.
//

import Testing
import Foundation
@testable import Devtail

@Suite("TaskBoardStore")
@MainActor
struct TaskBoardStoreTests {

    private static let root = URL(fileURLWithPath: "/fake/project")

    private func makeStore(files: [String: String] = [:]) -> (TaskBoardStore, MockTaskBoardFileAccess) {
        let mock = MockTaskBoardFileAccess()
        let store = TaskBoardStore(root: Self.root, fileAccess: mock)
        for (relative, content) in files {
            mock.files[Self.root.appendingPathComponent(relative)] = content
        }
        return (store, mock)
    }

    @Test("refresh loads and parses the board file")
    func refreshLoads() async {
        let (store, _) = makeStore(files: [".devtail/tasks.md": "## Pending\n- [ ] a\n"])
        store.refresh()
        await store.ioTask?.value
        #expect(store.fileExists == true)
        #expect(store.board?.tasks(in: .pending).map(\.title) == ["a"])
    }

    @Test("refresh with a missing file reports fileExists false and no board")
    func refreshMissingFile() async {
        let (store, _) = makeStore()
        store.refresh()
        await store.ioTask?.value
        #expect(store.fileExists == false)
        #expect(store.board == nil)
    }

    @Test("cancelled refresh does not assign")
    func cancelledRefreshDoesNotAssign() async {
        let (store, mock) = makeStore(files: [".devtail/tasks.md": "## Pending\n- [ ] a\n"])
        mock.readDelayNanoseconds = 50_000_000
        store.refresh()
        // Capture before cancel(): cancel() nils the handle, and the test
        // must await the cancelled task to deterministically observe that
        // it finished WITHOUT assigning.
        let inFlight = store.ioTask
        store.cancel()
        await inFlight?.value
        #expect(store.board == nil)
    }

    @Test("two rapid mutations both survive (writes are serialized)")
    func rapidMutationsCompose() async {
        let (store, mock) = makeStore(files: [".devtail/tasks.md": TaskBoardParser.render(.empty)])
        store.refresh()
        await store.ioTask?.value
        store.addTask(title: "first")
        store.addTask(title: "second")
        await store.ioTask?.value
        #expect(store.board?.tasks(in: .pending).map(\.title) == ["first", "second"])
        let written = mock.files[store.boardURL] ?? ""
        #expect(written.contains("- [ ] first"))
        #expect(written.contains("- [ ] second"))
    }

    @Test("createBoard writes the template and loads it")
    func createBoardWritesTemplate() async {
        let (store, mock) = makeStore()
        store.createBoard()
        await store.ioTask?.value
        #expect(mock.files[store.boardURL] == TaskBoardParser.render(.empty))
        #expect(store.board != nil)
        #expect(store.fileExists == true)
    }

    @Test("addTask writes the updated board through to the file")
    func addTaskWritesThrough() async {
        let (store, mock) = makeStore(files: [".devtail/tasks.md": TaskBoardParser.render(.empty)])
        store.refresh()
        await store.ioTask?.value
        store.addTask(title: "from ui")
        await store.ioTask?.value
        #expect(store.board?.tasks(in: .pending).map(\.title) == ["from ui"])
        #expect(mock.files[store.boardURL]?.contains("- [ ] from ui") == true)
    }

    @Test("moveTask relocates and persists")
    func moveTaskPersists() async {
        let (store, mock) = makeStore(files: [".devtail/tasks.md": "## Pending\n- [ ] a\n"])
        store.refresh()
        await store.ioTask?.value
        let id = store.board!.tasks(in: .pending)[0].id
        store.moveTask(id: id, to: .doing)
        await store.ioTask?.value
        #expect(store.board?.tasks(in: .doing).map(\.title) == ["a"])
        let written = mock.files[store.boardURL] ?? ""
        #expect(written.range(of: "## Doing\n- [ ] a") != nil)
    }

    @Test("failed write re-refreshes from disk so UI never drifts from the file")
    func failedWriteReRefreshes() async {
        let original = "## Pending\n- [ ] a\n"
        let (store, mock) = makeStore(files: [".devtail/tasks.md": original])
        store.refresh()
        await store.ioTask?.value
        mock.failWrites = true
        store.addTask(title: "will not stick")
        await store.ioTask?.value
        #expect(store.board?.tasks(in: .pending).map(\.title) == ["a"])
        #expect(mock.files[store.boardURL] == original)
    }

    @Test("archiveDone appends to the archive with a date heading and clears Done")
    func archiveDoneAppendsAndClears() async {
        let (store, mock) = makeStore(files: [".devtail/tasks.md": "## Done\n- [x] shipped\n"])
        store.refresh()
        await store.ioTask?.value
        store.archiveDone(on: Date(timeIntervalSince1970: 1_752_796_800))
        await store.ioTask?.value
        let archive = mock.files[store.archiveURL] ?? ""
        #expect(archive.contains("## 2026-07-18"))
        #expect(archive.contains("- [x] shipped"))
        #expect(store.board?.tasks(in: .done).isEmpty == true)
        #expect(mock.files[store.boardURL]?.contains("shipped") == false)
    }

    @Test("archiveDone with a failed append leaves the board and file untouched")
    func archiveAppendFailureLeavesBoard() async {
        let original = "## Done\n- [x] shipped\n"
        let (store, mock) = makeStore(files: [".devtail/tasks.md": original])
        store.refresh()
        await store.ioTask?.value
        mock.failAppends = true
        store.archiveDone(on: Date(timeIntervalSince1970: 1_752_796_800))
        await store.ioTask?.value
        #expect(store.board?.tasks(in: .done).map(\.title) == ["shipped"])
        #expect(mock.files[store.boardURL] == original)
    }

    @Test("archiveDone with an empty Done section is a no-op")
    func archiveEmptyDoneNoop() async {
        let (store, mock) = makeStore(files: [".devtail/tasks.md": TaskBoardParser.render(.empty)])
        store.refresh()
        await store.ioTask?.value
        store.archiveDone(on: Date(timeIntervalSince1970: 1_752_796_800))
        await store.ioTask?.value
        #expect(mock.files[store.archiveURL] == nil)
    }
}
```

- [ ] **Step 2: Run the suite to verify it fails to compile**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -20`
Expected: compile FAILURE — `TaskBoardFileAccessing`, `TaskBoardStore` not found.

- [ ] **Step 3: Implement the seam**

Create `Devtail/Features/Workspace/Services/TaskBoardFileAccess.swift`:

```swift
//
//  TaskBoardFileAccess.swift
//  Devtail
//
//  Injection seam for TaskBoardStore: the production implementation does
//  real disk I/O (off the main actor — these are async and the work is
//  plain FileManager/String I/O), tests substitute an in-memory double.
//  Mirrors the GitStatusReading seam rationale.
//

import Foundation

protocol TaskBoardFileAccessing: Sendable {
    func read(at url: URL) async -> String?
    func write(_ text: String, to url: URL) async -> Bool
    func append(_ text: String, to url: URL) async -> Bool
}

struct TaskBoardFileAccess: TaskBoardFileAccessing {

    init() {}

    func read(at url: URL) async -> String? {
        await Self.onIOQueue {
            try? String(contentsOf: url, encoding: .utf8)
        }
    }

    /// Creates intermediate directories (.devtail/) as needed. Atomic so a
    /// crash mid-write never leaves a truncated board.
    func write(_ text: String, to url: URL) async -> Bool {
        await Self.onIOQueue {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try text.write(to: url, atomically: true, encoding: .utf8)
                return true
            } catch {
                Log.store.error("task board write failed at \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
    }

    func append(_ text: String, to url: URL) async -> Bool {
        await Self.onIOQueue {
            let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try (existing + text).write(to: url, atomically: true, encoding: .utf8)
                return true
            } catch {
                Log.store.error("task board append failed at \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
    }

    /// Runs blocking file I/O on a utility queue and resumes the caller —
    /// same shape as GitStatusReader.run's continuation bridge.
    private static func onIOQueue<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: work())
            }
        }
    }
}
```

Note: `Log.store` already exists (Core/Logging/Log.swift). If the compiler cannot find it, check the category list in that file and use the closest existing category — do not add a new one in this task.

- [ ] **Step 4: Implement the store**

Create `Devtail/Features/Workspace/Stores/TaskBoardStore.swift`:

```swift
//
//  TaskBoardStore.swift
//  Devtail
//
//  Observable task-board state for the workspace side panel. Composed
//  into WorkspaceSession like FileTreeStore/FileSearchStore. The file is
//  the source of truth: every mutation renders and writes the whole
//  board, and a failed write re-refreshes from disk so the UI never
//  shows state the file does not have. Explicit refresh only (no file
//  watcher) — same model as the git/Claude cards.
//

import Foundation

@Observable
final class TaskBoardStore {

    let boardURL: URL
    let archiveURL: URL
    private let fileAccess: TaskBoardFileAccessing

    /// Nil until the first successful load, and nil when the file does
    /// not exist — pair with `fileExists` to tell those apart.
    private(set) var board: TaskBoard?
    private(set) var fileExists = false

    /// In-flight I/O task (refresh or mutation), exposed read-only so
    /// tests await completion instead of sleeping. Serialized: every
    /// operation cancels-or-chains behind the previous one by replacing
    /// this handle after awaiting its own work.
    @ObservationIgnored private(set) var ioTask: Task<Void, Never>?

    init(root: URL, fileAccess: TaskBoardFileAccessing = TaskBoardFileAccess()) {
        let devtailDir = root.appendingPathComponent(".devtail", isDirectory: true)
        self.boardURL = devtailDir.appendingPathComponent("tasks.md")
        self.archiveURL = devtailDir.appendingPathComponent("tasks-archive.md")
        self.fileAccess = fileAccess
    }

    /// Reload from disk. Cancels any in-flight operation; assigns only
    /// when not cancelled (no-assign-when-cancelled, like refreshGitStatus).
    func refresh() {
        ioTask?.cancel()
        ioTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let text = await self.fileAccess.read(at: self.boardURL)
            guard !Task.isCancelled else { return }
            self.fileExists = text != nil
            self.board = text.map(TaskBoardParser.parse)
        }
    }

    /// Writes the empty template (first-use path), then loads it.
    func createBoard() {
        ioTask?.cancel()
        ioTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let template = TaskBoardParser.render(.empty)
            guard await self.fileAccess.write(template, to: self.boardURL) else { return }
            guard !Task.isCancelled else { return }
            self.fileExists = true
            self.board = TaskBoardParser.parse(template)
        }
    }

    func addTask(title: String) {
        mutate { $0.add(title: title) }
    }

    func moveTask(id: UUID, to target: TaskState) {
        mutate { $0.move(id: id, to: target) }
    }

    /// Archives Done tasks: append to the archive file under a dated
    /// heading FIRST, and only rewrite the board when that append
    /// succeeded — a failed archive must never lose tasks. NOT optimistic
    /// (unlike `mutate`): the board keeps its Done tasks until the append
    /// lands.
    func archiveDone(on date: Date) {
        guard var working = board, !working.tasks(in: .done).isEmpty else { return }
        let removed = working.removeDoneTasks()
        let heading = Self.archiveDateFormatter.string(from: date)
        let block = "## \(heading)\n" + removed.map { "- [x] \($0.title)" }.joined(separator: "\n") + "\n\n"
        let previous = ioTask
        ioTask = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return }
            guard await self.fileAccess.append(block, to: self.archiveURL) else { return }
            if await self.fileAccess.write(TaskBoardParser.render(working), to: self.boardURL) {
                self.board = working
            } else {
                await self.refreshFromDisk()
            }
        }
    }

    /// Cancels any in-flight I/O — called from session teardown.
    func cancel() {
        ioTask?.cancel()
        ioTask = nil
    }

    /// Shared mutation path, optimistic + serialized: the board is
    /// updated in place immediately (so rapid successive mutations
    /// compose instead of deriving from a stale copy), and the rendered
    /// snapshot is written behind any in-flight write (FIFO — the last
    /// snapshot contains all prior changes, so last-write-wins is
    /// correct). A failed write re-refreshes from disk so the UI never
    /// drifts from the file for long.
    private func mutate(_ change: (inout TaskBoard) -> Void) {
        guard var working = board else { return }
        change(&working)
        board = working
        let snapshot = working
        let previous = ioTask
        ioTask = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return }
            if await !self.fileAccess.write(TaskBoardParser.render(snapshot), to: self.boardURL) {
                await self.refreshFromDisk()
            }
        }
    }

    @MainActor
    private func refreshFromDisk() async {
        let text = await fileAccess.read(at: boardURL)
        fileExists = text != nil
        board = text.map(TaskBoardParser.parse)
    }

    /// Archive headings are calendar dates in UTC — stable regardless of
    /// the machine's locale.
    private static let archiveDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}
```

- [ ] **Step 5: Compose into the session**

In `Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift`:

After the `fileSearch` property (near line 95, alongside the other stores), add:

```swift
    /// Task board for this project's .devtail/tasks.md — loaded lazily by
    /// the tasks side panel, not at session creation.
    let taskBoard: TaskBoardStore
```

In `init`, after the `fileSearch` assignment (line ~137):

```swift
        self.taskBoard = TaskBoardStore(root: root)
```

In `close(projectId:)`, next to `session.cancelClaudeInfoRefresh()` (line ~471):

```swift
        session.taskBoard.cancel()
```

- [ ] **Step 6: Run the suite to verify it passes**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **` (571 + 12 = 583 tests).

- [ ] **Step 7: Commit**

```bash
git add Devtail/Features/Workspace/Services/TaskBoardFileAccess.swift Devtail/Features/Workspace/Stores/TaskBoardStore.swift Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift DevtailTests/Features/Workspace/MockTaskBoardFileAccess.swift DevtailTests/Features/Workspace/TaskBoardStoreTests.swift
git commit -m "feat(workspace): task board store with file-backed persistence"
```

---

### Task 3: Rail case + `TaskBoardPanel` UI

**Files:**
- Modify: `Devtail/Features/Workspace/Models/SidePanelView.swift` (add case)
- Modify: `Devtail/Features/Workspace/Views/Components/WorkspaceSidePanel.swift` (add switch arm)
- Create: `Devtail/Features/Workspace/Views/Components/TaskBoardPanel.swift`

**Interfaces:**
- Consumes: `TaskBoardStore` (`session.taskBoard`: `board`, `fileExists`, `refresh()`, `createBoard()`, `addTask(title:)`, `moveTask(id:to:)`, `archiveDone(on:)`), `TaskState` (`allCases`, `displayName`), `TaskItem` from Tasks 1-2; `DevtailTokens`, `SectionHeader`, `.buttonStyle(.icon)` conventions from the existing panels.
- Produces: view-only change; no new public API.

No unit tests — SwiftUI view body, verified at Javier's visual checkpoint (project convention).

- [ ] **Step 1: Add the rail case**

In `Devtail/Features/Workspace/Models/SidePanelView.swift`, replace the enum body:

```swift
enum SidePanelView: CaseIterable {
    case files
    case processes
    case tasks

    var icon: String {
        switch self {
        case .files: "folder"
        case .processes: "play.square.stack"
        case .tasks: "checklist"
        }
    }

    var help: String {
        switch self {
        case .files: "Files"
        case .processes: "Processes"
        case .tasks: "Tasks"
        }
    }
}
```

- [ ] **Step 2: Add the panel switch arm**

In `Devtail/Features/Workspace/Views/Components/WorkspaceSidePanel.swift`, extend the switch:

```swift
        case .tasks:
            TaskBoardPanel(session: session)
```

- [ ] **Step 3: Create the panel**

Create `Devtail/Features/Workspace/Views/Components/TaskBoardPanel.swift`:

```swift
//
//  TaskBoardPanel.swift
//  Devtail
//
//  Side-panel task board over .devtail/tasks.md: three state groups,
//  checkbox toggling (Done vs Pending), a move menu per task, archive
//  for the Done group, and quick-add into Pending. Refreshes on appear
//  so agent-written items show up when the panel opens.
//

import SwiftUI

struct TaskBoardPanel: View {
    let session: WorkspaceSession

    @State private var newTaskTitle = ""

    private var store: TaskBoardStore { session.taskBoard }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapMedium) {
                    header
                    if let board = store.board {
                        ForEach(TaskState.allCases, id: \.self) { state in
                            stateGroup(state, tasks: board.tasks(in: state))
                        }
                    } else if !store.fileExists {
                        emptyState
                    }
                }
                .padding(DevtailTokens.Spacing.cardPadding)
            }
            if store.board != nil {
                addField
            }
        }
        .task { store.refresh() }
    }

    private var header: some View {
        HStack {
            SectionHeader(title: "Tasks")
            Spacer()
            Button {
                store.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
            }
            .buttonStyle(.icon)
            .foregroundStyle(.secondary)
            .help("Reload the board from disk")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
            Text("No task board yet")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Button("Create task board") {
                store.createBoard()
            }
            .font(DevtailTokens.Typography.caption)
        }
    }

    private func stateGroup(_ state: TaskState, tasks: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
            HStack {
                Text("\(state.displayName) \u{00B7} \(tasks.count)")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .textCase(.uppercase)
                Spacer()
                if state == .done && !tasks.isEmpty {
                    Button {
                        store.archiveDone(on: Date())
                    } label: {
                        Image(systemName: "archivebox")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.icon)
                    .foregroundStyle(.secondary)
                    .help("Move done tasks to tasks-archive.md")
                }
            }
            if tasks.isEmpty {
                Text("Empty")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
            } else {
                ForEach(tasks) { task in
                    taskRow(task)
                }
            }
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DevtailTokens.Spacing.gapSmall) {
            Button {
                store.moveTask(id: task.id, to: task.state == .done ? .pending : .done)
            } label: {
                Image(systemName: task.state == .done ? "checkmark.square" : "square")
                    .font(.system(size: 12))
                    .foregroundStyle(task.state == .done
                        ? DevtailTokens.Colors.trafficGreen
                        : DevtailTokens.Colors.textSecondary)
            }
            .buttonStyle(.icon)
            .help(task.state == .done ? "Reopen (back to Pending)" : "Mark done")

            Text(task.title)
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(task.state == .done
                    ? DevtailTokens.Colors.textTertiary
                    : DevtailTokens.Colors.textSecondary)
                .strikethrough(task.state == .done)
                .lineLimit(2)
                .help(task.title)

            Spacer(minLength: 0)

            Menu {
                ForEach(TaskState.allCases.filter { $0 != task.state }, id: \.self) { target in
                    Button("Move to \(target.displayName)") {
                        store.moveTask(id: task.id, to: target)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10))
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var addField: some View {
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            TextField("Add a task", text: $newTaskTitle)
                .textFieldStyle(.plain)
                .font(DevtailTokens.Typography.caption)
                .onSubmit(submitNewTask)
            Button(action: submitNewTask) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(.icon)
            .foregroundStyle(.secondary)
            .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            .help("Add to Pending")
        }
        .padding(DevtailTokens.Spacing.cardPadding)
        .background(DevtailTokens.Colors.titleBar)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DevtailTokens.Colors.borderSubtle)
                .frame(height: DevtailTokens.BorderWidth.default)
        }
    }

    private func submitNewTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        store.addTask(title: title)
        newTaskTitle = ""
    }
}
```

- [ ] **Step 4: Run the suite to verify everything still passes**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **` (583 tests).

- [ ] **Step 5: Commit**

```bash
git add Devtail/Features/Workspace/Models/SidePanelView.swift Devtail/Features/Workspace/Views/Components/WorkspaceSidePanel.swift Devtail/Features/Workspace/Views/Components/TaskBoardPanel.swift
git commit -m "feat(workspace): task board side panel with rail access"
```
