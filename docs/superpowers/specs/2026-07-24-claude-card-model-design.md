# Claude Card: Current Model Row — Design

Date: 2026-07-24
Status: Approved (Javier, 2026-07-24 — "el modelo real de la última sesión")

## Problem

The dashboard Claude card shows skills, agents, commands, MCP servers, and token
totals, but not which Claude model the project is actually running. Javier wants
the current model visible on the card.

## Decision

Show the model **actually used in the most recent session**, read from the
project's Claude Code transcripts — not the settings-configured model, which
goes stale when the user switches models mid-session with `/model`.

## Design

### 1. Data

- `ClaudeIntrospection` gains `currentModel: String?`.
- `ClaudeProjectIntrospector` finds the newest `.jsonl` (by modification date)
  in `~/.claude/projects/<encoded-root>/` and scans it **from the last line
  backwards** for the first line carrying `message.model` (assistant entries).
  Lines without it, or that fail to parse, are skipped — transcripts are
  best-effort data, never a hard failure (same contract as `TokenAggregator`).
- No new I/O surface: the introspector already enumerates and reads these
  files for token aggregation.

### 2. Display name mapping

A small static map from known model ids to short names, falling back to a
cleaned raw id for unknown/future models:

| id prefix | display |
|---|---|
| `claude-fable-5` | Fable 5 |
| `claude-opus-5` | Opus 5 |
| `claude-sonnet-5` | Sonnet 5 |
| `claude-haiku-4-5` | Haiku 4.5 |
| `claude-opus-4` (incl. 4.x) | Opus 4.x per id |
| anything else | raw id with `claude-` prefix stripped |

### 3. UI

One new row in the Claude card (`WorkspaceDashboardColumn`), directly above
the tokens row, using the existing row style: `cpu` SF Symbol + display name
(e.g. "Fable 5"). When `currentModel` is nil (no transcripts yet), the row is
omitted — matching the card's best-effort pattern.

### 4. Out of scope

- Per-agent-tab model attribution (the card is a project aggregate).
- Reading settings files.
- Live refresh beyond the card's existing refresh mechanism.

### 5. Testing

- Last-`message.model` extraction: last line wins, non-model and unparsable
  lines skipped, empty file → nil.
- Newest-transcript selection by modification date.
- Display-name mapping including the unknown-id fallback.
- Introspection wiring: `currentModel` populated end-to-end via the existing
  introspector test seams; nil when the project has no transcript dir.
