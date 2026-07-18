# Branch Card Enrichment — Design

**Date:** 2026-07-18
**Status:** Approved by Javier (scope B: branch list + last commit, read-only)

## Problem

The workspace Branch card shows the current branch name, a bare local branch
count ("6 branches"), clean/dirty state, and ahead/behind. The count is not
representative: it says how many branches exist but not which ones, and there
is no signal of where work last stopped. Javier asked for more useful
information in this zone.

## Scope decision

Three options were considered:

- **A** — expandable branch list only.
- **B** — A plus last commit of the current branch (subject + relative time). **Chosen.**
- **C** — B plus branch checkout from the app. **Rejected for now**: it would
  be the first git write action in Devtail, with its own error surface
  (dirty working tree, conflicts). Deferred until explicitly requested.

The card stays read-only.

## Data layer — `GitStatusReader`

`GitStatus` changes shape:

| Field | Change |
| --- | --- |
| `localBranchCount: Int` | **Removed** — replaced by `localBranches.count`. |
| `localBranches: [String]` | **New** — local branch names, in `git branch` output order. |
| `lastCommitSubject: String?` | **New** — subject line of `HEAD`'s commit. |
| `lastCommitDate: Date?` | **New** — committer date of `HEAD`'s commit. |

Reader changes:

- The existing `git branch --format=%(refname:short)` invocation already
  produces the names; `parseBranchCount` becomes `parseBranchList(_:) -> [String]`
  (trim, drop blank lines, preserve order).
- One new invocation: `git log -1 --format=%s%x09%ct` (subject, tab, unix
  committer timestamp). New pure parser
  `parseLastCommit(_:) -> (subject: String, date: Date)?` returning nil on
  malformed output. Both fields are nil when the invocation fails (e.g. a
  repo with zero commits) — the card simply omits the row, matching how
  ahead/behind already degrades when there is no upstream.
- Both parsers stay `static` pure functions: the TDD targets. `status(in:)`
  remains best-effort/manual-tested, per the existing contract in the file
  header.

## UI — `WorkspaceDashboardColumn.branchSection`

- The "6 branches" text becomes a `DisclosureGroup` following the exact
  pattern of `claudeCategoryRow`: collapsed label "N branches", expands to
  the name list (`captionSmall`, `lineLimit(1)`).
- In the expanded list the current branch is highlighted: accent color plus
  a `checkmark` prefix; other branches use `textSecondary`.
- New last-commit row under the clean/dirty line: subject truncated to one
  line plus relative time ("2 hours ago") via `RelativeDateTimeFormatter`
  with `unitsStyle = .abbreviated`. Hidden when `lastCommitSubject` is nil.
- Clean/dirty, ahead/behind, and the refresh button are unchanged.

## Testing

- `GitStatusReaderTests`: `parseBranchList` (normal output, empty output,
  blank lines, trailing newline) and `parseLastCommit` (normal output, empty,
  missing tab, non-numeric timestamp).
- `MockGitStatusReader` and `WorkspaceSessionGitStatusTests` updated for the
  new `GitStatus` shape — wiring behavior is already covered there and does
  not change.
- UI is verified at Javier's visual checkpoint, per project convention.

## Out of scope

- Branch checkout or any git write action (option C).
- Remote branches, per-branch ahead/behind, commit author/hash display.
