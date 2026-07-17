# File-Name Search in the Files Panel — Design

**Date**: 2026-07-17
**Branch**: `feat/file-search`
**Roadmap**: Info-panel roadmap, feature 4 of 4 (approved 2026-07-16).

## Intent

Cmd+P-style file-name search (not content search) scoped to the workspace project root.
Typing a query in the Files side panel replaces the tree with a flat list of matching
files; tapping (or pressing Return on) a result opens it in the viewer tab.

## Key constraint discovered

`FileTreeStore` loads directories lazily — children of unexpanded folders are never in
the model. Search therefore performs its own recursive walk of the project root instead
of filtering `FileTreeNode`s.

## Decisions

1. **Flat result list, not a synthesized hierarchy.** "Cmd+P style" is the stated
   inspiration; a flat list of `name — relative/parent/dir` rows communicates matches in
   unexpanded folders better than a rebuilt tree. The tree returns as soon as the query
   is cleared (Escape or empty field).
2. **Walk via the existing `DirectoryLister` protocol.** The walker recurses with the
   same injected lister the tree uses (`FileManagerDirectoryLister` in production,
   `MockDirectoryLister` in tests) — same filesystem view, fully testable, no new IO
   primitives.
3. **Walk rules**: skip `.git` directories entirely; respect the same `maxDepth = 32`
   guard as the tree; cap results at 100 (stop walking once reached, show a "first 100"
   hint). Everything else — including dotfiles and `node_modules` — stays searchable,
   consistent with the tree, which has no ignore layer.
4. **Async + cancellable, mirroring the `gitStatus`/`claudeInfo` seam**: each query
   change cancels the in-flight walk task and starts a new one after a 250 ms debounce.
   Matching is case-insensitive substring on the file *name* (trimmed query), same
   normalization as `ProjectFilterEngine`.
5. **Cmd+P from anywhere in the workspace window**: switches the side panel to `.files`
   and focuses the search field. Cross-view focus travels through an incrementing
   `searchFocusRequest` counter on the store; `FileTreeColumn` observes it with
   `onChange` and drives a local `@FocusState`.
6. **Keyboard on results**: Down/Up move a highlighted index, Return opens it,
   Escape clears the query and restores the tree (pattern from `MenuBarRootView`).

## Components

| Piece | Location | Role |
| --- | --- | --- |
| `FileNameMatcher` | `Features/Workspace/Stores/` | Pure: query normalization + name match |
| `FileSearchWalker` | `Features/Workspace/Services/` | Recursive walk over `DirectoryLister`, skip/`maxDepth`/cap rules, returns `[FileSearchResult]` (name + relative dir + absolute path) |
| `FileSearchStore` | `Features/Workspace/Stores/` | `@Observable`: `query`, `results`, `isSearching`, `searchFocusRequest`, debounce + task cancellation |
| `FileTreeColumn` changes | existing | `SearchField` under the header; query active → result list (icon, name, dimmed relative dir, highlight, cap hint, empty state) instead of tree |
| `WorkspaceSession` | existing | owns `let fileSearch: FileSearchStore` (root + lister at init) |
| Cmd+P registration | `WorkspaceRootView` | hidden button `.keyboardShortcut("p", modifiers: .command)` → `sidePanel = .files` + `fileSearch.requestFocus()` |

Result rows reuse `WorkspaceSession.openFile(at:)` — the exact seam `FileTreeNodeRow`
uses — and the existing `FileIcon` typing for the icon.

## Out of scope

Content search, fuzzy scoring/ranking (results keep walk order: dirs-first,
case-insensitive name), ignore files (.gitignore), persistence of the query across
panel switches beyond the session object's lifetime.

## Tests

- `FileNameMatcherTests` — trim, case-insensitivity, substring, empty query.
- `FileSearchWalkerTests` with `MockDirectoryLister` — recursion, `.git` skip, depth
  cap, result cap short-circuit, relative-dir construction, lister-error tolerance
  (a folder that fails to list is skipped, walk continues).
- `FileSearchStoreTests` — query drives results, clearing restores idle, cancellation
  on rapid query change (via walker seam), focus-request counter.
