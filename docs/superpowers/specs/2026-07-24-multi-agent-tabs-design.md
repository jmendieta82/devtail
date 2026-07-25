# Multiple Agent Tabs per Project — Design

Date: 2026-07-24
Status: Approved (Javier, 2026-07-24)

## Problem

Devtail supports exactly one Claude agent session per project: `WorkspaceSession.agent`
is a single non-optional `TerminalSession`, and the `WorkspaceTab.agent` case is
parameterless, so a second instance is structurally unrepresentable. Javier often works
with several Claude sessions in the same project and wants a "+" in the tab row that
opens additional agent tabs.

## Approach

Mirror the existing multi-instance pattern used for dev-server processes
(`ProcessSupervisor` / `ManagedProcess` / `WorkspaceTab.process(UUID)`), which already
proves per-instance tabs, close buttons, restart, and exit-identity guards in this
codebase.

Rejected alternatives:

- Keep the singleton `agent` and add `extraAgents: [...]` — creates permanent two-tier
  logic (primary vs extra) that every future feature pays for.
- Generalize `ProcessSupervisor` to own agents — processes come from persisted
  `WorkspacePane` definitions; agents are ephemeral with their own resume semantics.
  Different lifecycles, no shared owner.

## Design

### 1. Model

New `AgentInstance` (`@Observable`, `Identifiable`, final class):

- `id: UUID`
- `title: String` — auto-generated: first instance "agent", then "agent 2", "agent 3", …
  (monotonic counter per workspace session; numbers are not reused after close).
  Renaming is out of scope.
- `session: TerminalSession`
- `exited: Bool`
- `claudeSessionId: UUID` — generated at creation, passed to the CLI via `--session-id`.

`WorkspaceSession` replaces `agent: TerminalSession` + `agentExited: Bool` with
`private(set) var agents: [AgentInstance]`. `openSession(for:)` seeds the first
instance eagerly, exactly like today. Nothing is persisted; agent tabs are ephemeral
across app restarts (unchanged from today).

Invariant: `agents.count >= 1` for an open session. The last agent tab cannot be
closed.

### 2. Tabs and navigation

- `WorkspaceTab.agent` becomes `.agent(UUID)`.
- The tab row renders `ForEach(session.agents)` chips. Each chip has a close button,
  hidden (or disabled) when `agents.count == 1`. A "+" affordance next to the agent
  chips creates a new instance and selects it.
- The ~6 hardcoded `.agent` fallback sites (`WorkspaceRootView` 148/157/196,
  `WorkspaceSessionsHolder` 173/408, `WorkspaceSettingsTabView` 58) route through a
  resolver on `WorkspaceSession` returning the first agent's tab.
- ⇧⌘A selects the first agent tab. ⇧⌘R restarts (with context) the agent of the
  currently selected tab; if the selected tab is not an agent, it falls back to the
  first agent (today's behavior generalized).
- The Shortcuts card copy in `WorkspaceDashboardColumn` stays in sync.

### 3. Launch and restart

- `agentLaunchCommand` gains a token-aware `--session-id <uuid>` append at creation
  (same append mechanism used today for `--continue`).
- "Restart with context" uses `--resume <claudeSessionId>` instead of `--continue`,
  so each tab resumes exactly its own conversation. Known caveat (accepted): if the
  user switches conversations with `/resume` inside the terminal, the tracked id goes
  stale and restart-with-context returns to the tracked conversation.
- Plain restart generates a fresh `claudeSessionId`.
- The remount fix from 66561b8 is preserved per instance: each agent host in the
  `ZStack` `ForEach` keeps `.id(ObjectIdentifier(instance.session))`.
- `wireAgentExit` becomes per-instance with the same session-identity guard
  (`instance.session === terminal`).

### 4. Lifecycle and quit correctness

- `openAgent(projectId:)` — creates, starts, wires, and returns a new instance
  (mirrors `openInteractive`).
- `closeAgent(projectId:agentId:)` — terminates the session and removes the instance.
  Refused when it is the last agent. If the closed tab was selected, selection moves
  to a neighboring agent tab.
- `restartAgent(projectId:agentId:resume:)` — replaces the instance's session wholesale
  (today's mechanism, keyed by agent id).
- `close(projectId:)` terminates every agent instance.
- `liveTerminalSessions()` and `shutdownAll(deadline:completion:)` iterate all agent
  instances. This is a quit-correctness fix: counting a single agent would leak
  orphaned `claude` processes past app quit.
- `deadAgentOverlay` resolves per instance: each dead agent tab shows its own
  Restart / Restart with context overlay.

### 5. Out of scope

- Renaming agent tabs.
- Per-instance agent command override (`AppSettings.agentCommand` stays global).
- Per-instance token usage attribution (`ClaudeProjectIntrospector` dashboard numbers
  remain a per-project aggregate).
- Persisting agent tabs across app restarts.
- Split view (tabs only, per Javier's choice).

### 6. Testing

On top of `MockTerminalEngine` in `WorkspaceSessionsHolderTests`:

- Open session seeds exactly one agent; "+" adds instances with correct titles.
- Close removes the instance and terminates its session; last instance cannot close;
  selection moves to a neighbor when the selected tab closes.
- Restart replaces the session for the right instance only; exit-wire identity guard
  holds across restarts.
- `agentLaunchCommand`: `--session-id` appended token-aware at creation; restart with
  context uses `--resume <id>`; plain restart rotates the id.
- Quit accounting: `liveTerminalSessions()` counts every live agent across projects.
- Fallback resolver: tab fallbacks land on the first agent.
