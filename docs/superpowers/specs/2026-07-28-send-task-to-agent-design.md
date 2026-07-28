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

### 2. Pending-input mailbox on the agent instance

The task board and the agent are different tabs, so the destination
`AgentTerminalView` may not be mounted when the user clicks the menu item.
A direct method call is therefore not possible.

The codebase already solves exactly this shape with `envConflictPath` +
`consumeEnvConflict(for:)` on `WorkspaceSession`: a pending value parked on
the model, consumed one-shot by the view when it mounts or observes a change.

Mirror it on `AgentInstance`:

- `var pendingInput: String?` — set by the send action.
- `func consumePendingInput() -> String?` — returns and clears in one step, so
  a second call yields nil. One-shot by design: a remount must not re-paste.

`AgentTerminalView` consumes it in `.onChange` (already mounted) and
`.onAppear` (mounting fresh), then calls `sendBracketedText`.

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
  → session.sendTask(text:toAgent:)
      → agents[i].pendingInput = "Tarea del board: <title>"
      → session.selectedTab = .agent(id)
  → AgentTerminalView (mounts, or observes change if already mounted)
      → consumePendingInput()
      → sendBracketedText(...)
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
- **Agent dies between menu render and click** — `pendingInput` is set on a
  dead instance and never consumed. Harmless: the value is dropped when the
  instance is released, and a restart spawns a fresh instance.
- **Send while the target tab is already showing** — `.onChange` fires, paste
  lands, tab selection is a no-op.
- **Two sends in a row before consumption** — the second overwrites the first.
  Acceptable: the user sees the tab switch after the first click, so the
  interleaving is not reachable in practice.

## Testing

Unit-testable (existing `TaskBoardStoreTests` /
`WorkspaceSessionsHolderTests` suites):

- `pendingInput` lands on the targeted agent and no other.
- `consumePendingInput()` returns the text and clears it; a second call
  returns nil.
- Exited agents are excluded from the destination list.
- Prompt formatting carries the `Tarea del board: ` prefix and the exact title.
- Tab selection moves to the targeted agent.

Not unit-testable: the bracketed-paste write itself needs a live PTY — the
same seam already uncovered for drag & drop and image paste. Covered by the
user's visual checkpoint.
