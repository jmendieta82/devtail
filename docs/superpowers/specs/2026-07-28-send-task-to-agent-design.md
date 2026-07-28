# Send task to agent — design

Date: 2026-07-28
Status: approved, ready for planning

## Problem

Tasks live in `.devtail/tasks.md` and render in the task board tab. When the
user wants an agent to work on one of them, the only path today is retyping
the task title into the agent tab by hand.

Automatic injection at agent launch was considered and rejected: most sessions
are not about the board, so pushing six pending tasks into every agent's
opening context burns tokens and biases the agent toward work the user did not
ask for. The correct model is pull, not push — tasks reach the agent only when
the user explicitly sends one.

## Solution

A `Send to agent` action in the task card's existing `...` menu. It pastes the
task title into a chosen agent tab's prompt without submitting it, and selects
that tab.

## Non-goals

- Marking tasks done from the agent (no write path back to `tasks.md`).
- Sending priority or creation date — that metadata organizes the human's
  board, it is not useful agent context.
- Sending multiple tasks at once.
- Auto-submitting the prompt.

## Architecture

Three changes, all resting on patterns already present in the codebase.

### 1. Generalize the send channel

`AgentTerminalView.sendBracketedPath(_:)` (`AgentTerminalView.swift:82`) already
writes text to the agent PTY using a hand-rolled bracketed-paste wrap. It is
named and documented in terms of file paths because drag & drop and image paste
are its only current callers.

Rename it to `sendBracketedText(_:)`. Path callers keep working unchanged — a
path is just text. No behavior change to drag & drop or image paste.

### 2. Direct write through the session protocol

An earlier draft of this design routed the text through a `pendingInput`
mailbox on `AgentInstance`, mirroring `envConflictPath` /
`consumeEnvConflict(for:)`, on the assumption that the destination
`AgentTerminalView` might not be mounted when the menu item is clicked.

**That assumption is wrong.** `TerminalHostView` documents the retention
model: every terminal NSView stays permanently mounted for the life of the
session because the holder owns it, not SwiftUI. Tab switching changes what is
visible, never what exists. The destination view is therefore always reachable.

So the send is a direct call, and the mailbox is dropped entirely.

`TerminalSession` already exposes `writeToStdin(_ text: String)`
(`SwiftTermEngine.swift:88`), but it sends raw text. The agent prompt needs the
bracketed-paste wrap. Add a sibling to the protocol:

- `func sendBracketedText(_ text: String)` — bracketed-paste wrap when the
  running program enabled mode 2004, raw text otherwise.

`SwiftTermEngine.Session` implements it by forwarding to the
`AgentTerminalView` method from change 1; non-agent terminal views fall back to
`send(txt:)`. `MockTerminalEngine` records the calls, which is what makes the
send unit-testable.

### 3. Menu entry

In `TaskBoardTabView.swift:218`, inside the existing `Menu`, above the current
`Divider()`.

Destination list = `session.agents.filter { !$0.exited }`.

- Zero live agents → the entry is omitted entirely.
- Exactly one → a flat `Send to agent` button. No submenu, no extra click.
- Two or more → a `Send to` submenu with one item per agent, labeled with
  `instance.title` ("agent", "agent 2", …).

Exited agents are excluded because writing to a dead PTY is swallowed
silently — the worst outcome, since it looks like it worked.

## Data flow

```
Menu "Send to ▸ agent 2"
  → session.sendTask(title:toAgent:)
      → instance.session.sendBracketedText("Tarea del board: <title>")
      → session.selectedTab = .agent(id)
  → AgentTerminalView (already mounted — retention model)
      → text lands in the prompt, unsubmitted
```

Tab selection is part of the action, not a side effect. Without it the click
produces no visible feedback and reads as a no-op.

## Prompt format

```
Tarea del board: <task title>
```

A short context prefix, no imperative instruction. The user completes the
prompt before submitting.

## Error handling

- **No live agents** — menu entry absent; nothing to fail.
- **Agent dies between menu render and click** — the write reaches a dead PTY
  and is swallowed. Not worth defending against: the window is a few hundred
  milliseconds, and the dead-state overlay (`WorkspaceRootView.swift:324`)
  makes the situation visible the moment the tab is selected.
- **Send while the target tab is already showing** — the write lands, tab
  selection is a no-op.
- **Two sends in a row** — both land, concatenated in the prompt. The user
  sees the tab switch after the first click, so this is deliberate, not a race.

## Testing

Unit-testable via `MockTerminalEngine`, which records `sendBracketedText`
calls per session:

- The text reaches the targeted agent's session and no other.
- Prompt formatting carries the `Tarea del board: ` prefix and the exact title.
- Tab selection moves to the targeted agent.
- Exited agents are excluded from the destination list.
- Sending to an unknown agent id is a no-op.

Not unit-testable: the bracketed-paste escape sequences themselves need a live
PTY and a real `getTerminal()` — the same seam already uncovered for drag &
drop and image paste. Covered by the user's visual checkpoint.
