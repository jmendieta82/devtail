# Agent Restart: Dead-View Bug Fix + Restart with Context — Design

**Date:** 2026-07-21
**Status:** Approved by Javier (conversational design review)

## Problem

Two related failures around the agent pane lifecycle:

1. **Bug — restart mounts nothing.** `WorkspaceRootView` mounts the agent
   terminal as `TerminalHostView(terminalView: session.agent.view)`. When
   `restartAgent` replaces `session.agent` wholesale, SwiftUI keeps the
   representable's structural identity and only calls `updateNSView`, which
   deliberately ignores `terminalView` (retention model). The dead terminal's
   NSView stays mounted forever; the fresh agent runs invisibly. The user sees
   a black pane and a "Restart agent" button that appears to do nothing. The
   same latent bug exists in `restartInteractive` ("Restart shell").

2. **Missing feature — no context on restart.** Both the auto-start and the
   restart path launch the bare configured `agentCommand` (default `claude`),
   so a restarted agent always loses the conversation. Recovering context
   today requires editing the global setting to `claude -c`, quitting and
   relaunching the app — Javier's post-reinstall dance with two active
   projects.

## Design (approved: approach A)

### 1. Bug fix — representable identity

Key the terminal representables by their session's object identity:
`.id(ObjectIdentifier(session.agent))` on the agent `TerminalHostView`, and
`.id(ObjectIdentifier(interactive))` on the interactive one. Replacing the
session changes the id, SwiftUI discards the old representable and calls
`makeNSView` with the fresh view. Process-pane hosts are keyed by process id
already via ForEach identity and keep their views; no change there.

### 2. Restart with context

- `restartAgent(projectId:resume:)` gains a `resume` flag. When true, the
  launch command is the sanitized `agentCommand` plus ` --continue` — unless
  the configured command already contains `--continue` or a standalone `-c`
  token, in which case it is used as-is (no double flag).
- Dead-agent overlay gets two buttons: **Restart** (fresh) and **Restart with
  context** (resume).
- New Commands menu entry **Restart Agent with Context** (⇧⌘R), enabled
  whenever a workspace session exists. It terminates the current agent
  (alive, stuck, or dead) and relaunches with resume — the always-available
  escape hatch that replaces the Ctrl+C ritual.
- The Shortcuts card in the workspace dashboard gains the ⇧⌘R row (its doc
  comment demands the keyboard map stay in sync).

### 3. Out of scope

- Auto-`--continue` on workspace open (approach B) — rejected: changes the
  semantics of every open and behaves badly on projects with no prior
  conversation.
- Persisting/restoring agent sessions across app quits.

## Error handling

`--continue` in a project with no prior conversation is Claude's error to
report inside its own TUI; the pane shows whatever the process prints. No
special handling.

## Testing

- `WorkspaceSessionsHolderTests` (MockTerminalEngine) already cover
  `restartAgent`; extend with: resume appends ` --continue`; resume does not
  double the flag when the setting already has `--continue` or `-c`; fresh
  restart never appends.
- The representable-identity fix and the menu action are validated in
  Javier's manual checkpoint: kill the agent, restart from the overlay (pane
  must revive), then ⇧⌘R from a live agent (must relaunch with context).
