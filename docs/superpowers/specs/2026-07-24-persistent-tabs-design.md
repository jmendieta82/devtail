# Persistent Tabs — Design

Date: 2026-07-24
Status: Approved (Javier, 2026-07-24 — "las pestañas deben ser persistentes, solo yo las cierro")

## Rule

Any tab the user opens stays in the tab row until the user closes it with its
X. Switching tabs never removes a tab.

## Problem

The tasks and settings chips are drawn from the selection itself
(`WorkspaceRootView.swift:157-174`: `if session.selectedTab == .tasks { ... }`),
so selecting any other tab makes the chip's own existence condition false and
SwiftUI removes it in the same render pass. From the user's side the tab
"closes by itself". They are the only two tab kinds with no backing store —
agents (`session.agents`), processes (`supervisor.processes`), and files
(`session.openFiles`) all outlive selection.

## Design

### 1. Open-tab state

`WorkspaceSession` gains two flags:

```swift
/// Tasks/settings tabs stay in the row once opened — only their own X
/// removes them. Selection never closes a tab.
private(set) var isTasksTabOpen = false
private(set) var isSettingsTabOpen = false
```

Mutating API on `WorkspaceSession` (mirrors the open/close pattern used for
files and agents):

- `openTasks()` — sets the flag and selects `.tasks`.
- `closeTasks()` — clears the flag; if `.tasks` was selected, selection falls
  back to `firstAgentTab`.
- `openSettings()` / `closeSettings()` — same shape for `.settings`.

Opening is idempotent: opening an already-open tab just re-selects it.

### 2. Chips

The two `if session.selectedTab == …` blocks become
`if session.isTasksTabOpen { … }` / `if session.isSettingsTabOpen { … }`, with
the real chip contract instead of the inert one:

- `isSelected: session.selectedTab == .tasks` (was hardcoded `true`)
- `select: { session.selectedTab = .tasks }` (was a no-op `{}`)
- `close: { session.closeTasks() }` (was a selection reassignment)

### 3. Content mounting

`WorkspaceRootView`'s conditional content stays keyed on `selectedTab` — an
open-but-unselected tasks tab renders nothing, exactly like an unselected
file tab. Terminal views must stay mounted in the ZStack (scrollback), but
`TaskBoardTabView`/`WorkspaceSettingsTabView` have no PTY, so unmounting the
unselected one remains correct.

### 4. Entry points

The four places that set `.tasks`/`.settings` directly route through the new
open methods: `ActivityBar.swift:25,40` and `WorkspaceCommands.swift:41,61`
(⌘B tasks, ⌘S settings). `WorkspaceSettingsTabView`'s own dismiss
(`:58`) calls `closeSettings()`.

The ActivityBar highlight keeps reading `selectedTab`, so an open-but-
unselected tab is not highlighted — consistent with every other tab kind.

### 5. Session close

`WorkspaceSessionsHolder.close(projectId:)` needs no change: the flags live
on the session object that is discarded wholesale.

### 6. Out of scope

- Persisting open tabs across app restarts (tabs are per-session, as today).
- Reordering or dragging tabs.
- Process-chip behavior: process chips are already independent of selection
  (`WorkspaceRootView.swift:150` gates on `process.session != nil`). The user
  reported a process chip disappearing without opening Settings; no code path
  explains that, so this design adds diagnostic logging only (below) rather
  than guessing at a fix.

### 7. Diagnostics for the unexplained process-chip report

Add `Log.lifecycle` statements that make the next occurrence self-explaining:

- `ProcessSupervisor.close(_:)` already logs; add the caller context by
  logging in `reconfigure` the incoming pane ids versus the current process
  ids whenever it is about to close anything.

No behavior change — evidence only.

### 8. Testing

- Opening tasks then selecting an agent leaves `isTasksTabOpen == true`.
- `closeTasks()` clears the flag and moves selection to `firstAgentTab` only
  when tasks was selected; selection is untouched otherwise.
- Same pair for settings.
- Opening an already-open tab re-selects without duplicating state.
- Existing tests that assert selection fallbacks keep passing.
