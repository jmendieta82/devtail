# Project Task Board — Design

**Date:** 2026-07-18
**Status:** Approved by Javier (rail access + file-based storage + three states)

## Problem

During review sessions Javier keeps Scrum-like annotations: what is done,
what is in progress, what is pending. Agents (Claude Code) frequently
conclude with "queda pendiente X" and that item is lost unless someone
writes it down. He wants a per-project board inside Devtail where both he
and the agent can add and complete tasks.

## Decisions (locked with Javier)

1. **Storage: a markdown file in the project repo** (`.devtail/tasks.md`).
   The agent adds items by editing the file; Devtail renders and edits the
   same file. Versioned with git for free. (SwiftData-only was rejected:
   agents would have no natural write path.)
2. **Growth control**: done tasks are archived to `.devtail/tasks-archive.md`
   on explicit user action. The active file stays small; the archive is
   append-only history outside the hot read path.
3. **Access: a new icon in the workspace activity bar** (the VS Code-style
   rail). `ActivityBar` iterates `SidePanelView.allCases`, so a new enum
   case is the entire rail change.
4. **States: three** — Doing / Pending / Done — as markdown sections.

## File contract

`.devtail/tasks.md`, created from a template on first use:

```markdown
# Tasks

## Doing

## Pending

## Done
```

- The three section headings are exact matches (`## Doing`, `## Pending`,
  `## Done`), in any order in the file; rendering always writes them in
  Doing/Pending/Done order.
- A task line matches `- [ ] title` or `- [x] title` (case-insensitive
  `x`). Everything else — preamble before the first section, blank lines,
  non-task lines inside sections — is preserved verbatim on rewrite, in
  order, so agent- or hand-written notes are never destroyed.
- **The section is the source of truth for state**, not the checkbox.
  Rendering normalizes checkboxes: `- [x]` in Done, `- [ ]` elsewhere. An
  agent writing `- [x]` under Pending will see the task stay in Pending
  (unchecked) after Devtail's next rewrite — deliberate, one source of
  truth.
- Archive file: on "Archive done", all Done tasks are appended to
  `.devtail/tasks-archive.md` under a `## YYYY-MM-DD` heading (file and
  heading created as needed) and removed from `tasks.md`.

## Domain — `TaskBoardParser` (pure) + models

`Devtail/Features/Workspace/Models/TaskBoard.swift`:

- `TaskItem`: `id: UUID` (assigned at parse, stable within a load),
  `title: String`, `state: TaskState`.
- `TaskState: CaseIterable`: `.doing`, `.pending`, `.done` — carries the
  section heading string.
- `TaskBoard`: `preamble: [String]` (lines before the first known section)
  plus, per state, an ordered list of `TaskBoardLine` values —
  `.task(TaskItem)` or `.raw(String)` — so round-tripping preserves
  unknown content in place.
- Convenience accessors: `tasks(in state:) -> [TaskItem]`, mutations
  `add(title:)` (appends to Pending), `move(id:to:)` (appends to target
  section), `removeDoneTasks() -> [TaskItem]` (for archiving).

`Devtail/Features/Workspace/Services/TaskBoardParser.swift`:

- `static func parse(_ text: String) -> TaskBoard`
- `static func render(_ board: TaskBoard) -> String`
- Pure static functions — the TDD targets, mirroring the
  `GitStatusReader` parser pattern.

## File I/O and store

`Devtail/Features/Workspace/Services/TaskBoardFileAccess.swift`:

- `protocol TaskBoardFileAccessing: Sendable` with async
  `read(at: URL) -> String?`, `write(_ text: String, to: URL) -> Bool`,
  `append(_ text: String, to: URL) -> Bool`. Production implementation
  `TaskBoardFileAccess` uses `FileManager`/`String(contentsOf:)` off the
  main actor. The seam exists for store tests (mirrors `GitStatusReading`).

`Devtail/Features/Workspace/Stores/TaskBoardStore.swift` (`@Observable`,
composed into `WorkspaceSession` like `FileTreeStore`/`FileSearchStore`):

- State: `board: TaskBoard?` (nil = not loaded or file missing),
  `fileExists: Bool` so the panel can distinguish "no board yet" (offer
  Create) from "empty board".
- `refresh()`: cancels any in-flight load, reads + parses off the main
  actor, assigns on success; no-assign when cancelled (same contract as
  `refreshGitStatus`). In-flight task exposed read-only for tests.
- `createBoard()`: writes the template, then refreshes.
- Mutations `addTask(title:)`, `moveTask(id:to:)`, `archiveDone(on:)`:
  mutate the in-memory board, render, write the whole file; on write
  success keep the new board, on failure re-refresh from disk (never
  leave UI state the file does not have). `archiveDone(on:)` takes the
  date so it stays deterministic in tests; it appends to the archive
  file first and only removes from the board when that append succeeded.
- `cancel()`: called from `WorkspaceSessionsHolder.close(projectId:)`
  teardown, same as `fileSearch.cancelSearch()`.

External edits while the panel is open are picked up by the refresh
button or reopening the panel — no FSEvents watcher in v1, consistent
with the git/Claude cards' explicit-refresh model.

## UI

- `SidePanelView`: new case `.tasks`, icon `checklist`, help "Tasks". The
  rail button appears automatically.
- `WorkspaceSidePanel`: new switch arm → `TaskBoardPanel(session:)`.
- `Devtail/Features/Workspace/Views/Components/TaskBoardPanel.swift`:
  - Header: `SectionHeader("Tasks")` + refresh button (same icon-button
    recipe as the dashboard cards).
  - File missing → "No task board yet" + "Create task board" button.
  - Otherwise three groups (Doing, Pending, Done) listing task rows:
    checkbox toggle (checking moves to Done, unchecking moves to
    Pending), title (`caption`, `lineLimit(2)`), and a compact menu to
    move the task to any other state.
  - Done group header carries an "Archive" button when Done is non-empty.
  - Footer: text field "Add a task" — submit appends to Pending.
  - `.task { store.refresh() }` on appear so agent-written items show up
    when the panel opens.

## Agent integration (no code)

Convention snippet for project CLAUDE.md files (delivered to Javier at
the end of the cycle, not part of the Devtail build):

```markdown
## Task board
This project keeps a task board in `.devtail/tasks.md` (sections
`## Doing` / `## Pending` / `## Done`, lines `- [ ] title`). When work is
left pending or you finish something tracked there, update that file:
append new pending items as `- [ ] <title>` under `## Pending`.
```

## Testing

- `TaskBoardParserTests`: parse (template, tasks in each section, unknown
  lines preserved, missing sections, preamble, checkbox normalization on
  render, round-trip stability), mutations (add to Pending, move between
  states, removeDoneTasks).
- `TaskBoardStoreTests` with a mock `TaskBoardFileAccessing`: refresh
  assign-on-success, no-assign-when-cancelled, createBoard writes
  template, addTask/moveTask write-through, write-failure re-refresh,
  archiveDone appends before removing and skips removal on append
  failure.
- UI verified at Javier's visual checkpoint, per project convention.

## Out of scope

- FSEvents live watching (explicit refresh only in v1).
- Task metadata (assignee, dates, priorities), drag & drop, popover
  (menu bar) access, archive browsing UI — the archive is a plain file.
- Cross-project aggregated board.
