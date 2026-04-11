# Workspace UI Redesign — "Two Worlds"

**Date:** 2026-04-10
**Status:** Approved
**Approach:** C — "Two Worlds" (zero overlap between popover and dashboard)

---

## Context

The current workspace UI was built to be functional, not polished. Key problems:

- The popover is 320x220pt — cramped, buttons are tiny, layout preview consumes 60% of vertical space
- Information is redundant (preview + pane list show the same data)
- Flat visual hierarchy — everything has equal weight
- Layout preview truncates labels ("FRONT...", "API-NE...")
- No workspace activity indicator (fire-and-forget launch)
- Hard-coded dark theme with no system appearance support
- No contextual help for new users

## Design Principles

Inspired by CleanMyMac's design philosophy:

1. **Generous spacing** — air between sections, nothing cramped
2. **Contextual guide text** — every section has a descriptive subtitle with info icon
3. **Clear visual hierarchy** — hero elements are prominent, secondary info is subdued
4. **Sidebar with presence** — each item has visual weight, not a compressed list
5. **Tooltips on all action buttons** — hover reveals purpose

---

## Part 1: Popover — Accordion "Launch-Only"

### Philosophy

The popover is a remote control. Select project, see panes at a glance, launch. Zero configuration.

### Dimensions

- Width: **360pt** (up from 320pt)
- Height: dynamic, grows with content up to ~480pt max, then scrolls

### Structure

Single column. No split layout. No sidebar + detail panel.

**Top:** Search bar (existing, preserved)

**Middle:** Accordion list of projects

**Bottom:** "+ New project" link

### Project Row — Collapsed State

```
┌──────────────────────────────────────────┐
│  ●  Innclusiva          3 panes    ▸     │
└──────────────────────────────────────────┘
```

- Project color dot (left)
- Project name: SF Pro, 14pt, semibold
- Pane count: SF Pro, 12pt, tertiary color
- Chevron right (`▸`) that rotates to down (`▾`) when expanded
- If workspace is active: green activity dot overlaid on the project color dot (Slack/Discord "online" pattern)

### Project Row — Expanded State

```
┌──────────────────────────────────────────┐
│  ● Innclusiva            3 panes    ▾    │
│                                          │
│  ┌──────────┐ ┌───────────────┐ ┌──────┐ │
│  │Innclusiva│ │FRONT-COMERCIAL│ │API-  ││
│  │  main    │ │   develop     │ │NEST  ││
│  └──────────┘ └───────────────┘ └──────┘ │
│                                          │
│          ┌──────────────────┐            │
│          │    ▶  Launch      │            │
│          └──────────────────┘            │
│                                          │
│  Configure in Dashboard...               │
└──────────────────────────────────────────┘
```

- **Panes as horizontal pills/chips** that wrap if they don't fit in one line (custom `FlowLayout` using SwiftUI's `Layout` protocol — ~30 lines, no external dependency)
- Each chip: label on top (semibold), branch below (tertiary, with branch icon)
- If no branch detected, only label shown
- **Launch button**: centered, prominent — `accentGreen` background, white text, ~36pt height, rounded corners. THE primary action.
- "Configure in Dashboard..." — tertiary link, opens `DashboardRootView`

### Behavior

- Tap collapsed project → expands it, collapses any previously expanded (exclusive accordion)
- Always starts fully collapsed
- Search bar filters projects
- "+ New project" preserved at bottom

### What DISAPPEARS from the popover

- Split layout (sidebar + detail panel)
- Layout picker
- Slot assignment preview
- WORKSPACE / QUICK LINKS tabs
- Edit button
- Full pane rows (stack, environment, command, cwd details)
- Inline pane editing

---

## Part 2: Workspace Activity Detection (Green Dot)

### Service: `WorkspaceActivityMonitor`

New `@Observable` class that tracks which projects have active workspaces.

### Data

- `activeProjectIDs: Set<PersistentIdentifier>` — projects with running workspaces

### Detection Mechanism

1. **On Launch**: project added to "launched this session" set
2. **On popover open**: for each project in "launched" set, execute AppleScript check by working directory. If no Ghostty terminal matches the project's `directoryPath` → remove from set.
3. **Listener**: `NSWorkspace.didTerminateApplicationNotification` — if Ghostty terminates → clear entire set. All dots turn off.

### AppleScript Check

```applescript
tell application "Ghostty"
    if not running then return false
    set matchRoot to "{projectRoot}/"
    repeat with tm in every terminal
        if (working directory of tm) = "{projectRoot}" then return true
        if (working directory of tm) starts with matchRoot then return true
    end repeat
    return false
end tell
```

Uses `working directory` property exposed by Ghostty's AppleScript dictionary (verified working). Sandbox-safe — existing `com.apple.security.automation.apple-events` entitlement covers it.

### Optimization

Only checks projects that were launched this session, not all projects in the database.

### Visual Treatment

- **Inactive**: project color dot only (red, blue, purple, etc.)
- **Active**: green dot overlaid on color dot (like Slack/Discord online indicator). Does NOT replace the color — complements it.
- Applied in both popover accordion rows and dashboard sidebar.

---

## Part 3: Dashboard — Sidebar

### Dimensions

- Width: **~260pt**, dedicated column
- NavigationSplitView with sidebar + detail

### Project Item

```
┌──────────────────────────────────────────┐
│ ▎                                        │
│ ▎ ●  Innclusiva                          │
│ ▎ MainSideStack · 3 panes               │
│ ▎                                        │
└──────────────────────────────────────────┘
```

- **Color accent strip**: 3pt left border in project color (Notion/Linear pattern)
- **Name**: SF Pro, 14pt, semibold, primary color
- **Subtitle**: layout display name + pane count, SF Pro, 12pt, tertiary color
- **Green activity dot**: same treatment as popover
- **Selected state**: subtle highlight background, accent strip more prominent
- **Vertical padding**: ~12-14pt per item (generous, card-like feel)

### Header

```
PROJECTS                              +
```

- Section header + "+" button for new project
- Search bar below header

---

## Part 4: Dashboard — Detail Panel

The detail panel is a **scroll view** with vertical sections. No fixed height. No tabs.

### Section A: Header Hero

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   ● Innclusiva                              ▶  Launch      │
│   /Volumes/Datos/Proyectos Galeras/...                     │
│   Active                                                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

- **Color dot** (~14pt) + **Project name**: SF Pro, 18pt, semibold
- **Path**: Ubuntu Mono, 12pt, tertiary color
- **Status**: "Active" green chip if workspace is running. Nothing if inactive.
- **Launch button**: right-aligned with name. `accentGreen`, white text, play icon, ~36pt height. Always visible.
- **Edit button**: secondary, discrete. Opens project form (name, color, path).

Spacing after header: **24pt**

### Section B: Layout

**Guide text:**
```
LAYOUT
ⓘ Choose how your terminal panes are arranged when you launch this workspace.
```

- Header: SF Pro, 10pt, tertiary, tracking 0.5
- Guide text: SF Pro, 12pt, tertiary, with `info.circle` SF Symbol icon inline
- Gap between header and guide: 6pt

**Layout picker — larger thumbnails:**

- Thumbnail size: **100x65pt** (up from 60x40)
- **Layout name below** each thumbnail: SF Pro, 12pt, tertiary ("Full", "Halves", "Main+Side", "Quarters")
- Selected: `accentGreen` border 2pt + subtle lighter background
- Unselected: `borderSubtle`
- Tooltip on hover: layout name

**Assignment preview — larger with full labels:**

- Preview size: **~400x200pt** (up from 200x130)
- Labels render COMPLETE — no truncation
- Dropdown chevrons with better hit targets

**Guide text below preview:**
```
ⓘ Assign each pane to a slot. Unassigned panes won't open.
```

Spacing after layout section: **24pt**

### Section C: Panes

**Guide text:**
```
PANES
ⓘ Terminal sessions that will open when you launch this workspace.
```

**Panes as cards (not compressed rows):**

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   FRONT-COMERCIAL                     develop      dev     │
│   FRONT-COMERCIAL                                           │
│   npm run dev                                               │
│                                                      ✎  🗑  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

- **Line 1**: Label in SF Pro 14pt semibold + badges right-aligned (branch badge green, environment pill, stack badge)
- **Line 2**: Relative directory in Ubuntu Mono 13pt, tertiary color
- **Line 3**: Command in Ubuntu Mono 13pt, tertiary color. Hidden if no command.
- **Slot indicator**: discrete badge showing which layout slot ("Slot 1", "Slot 2")
- **Actions**: edit (pencil) and delete (trash) **always visible** (not hover-only). Hit target **28x28pt** (up from 18x18).
- **Card padding**: 14pt horizontal, 10pt vertical
- **Card spacing**: 8pt between cards
- **Card background**: glass effect with Liquid Glass

**Tooltips:**

| Button | Tooltip |
|--------|---------|
| ✎ (edit) | "Edit pane settings" |
| 🗑 (delete) | "Remove this pane" |

**"+ Add pane" button** below list:
- Outlined style, `borderSubtle`, `textSecondary`
- Tooltip: "Add a new terminal pane"

**Empty state:**
```
ⓘ No panes yet. Add your first terminal pane to get started.

        ┌──────────────────┐
        │    +  Add pane    │
        └──────────────────┘
```

**Inline editing**: tapping pencil expands the card in-place with edit fields (same fields as today, more space). No modal.

Spacing after panes section: **24pt**

### Section D: Quick Links

**Guide text:**
```
QUICK LINKS
ⓘ Bookmarks to URLs, files, or folders you access frequently for this project.
```

Same card-based visual treatment as panes. Functionality unchanged — only visual adaptation to the new spacing/card system.

---

## Part 5: Design System Updates

### Target

macOS 26 Tahoe (up from macOS 15 Sequoia)

### Theming

- **Eliminate all hardcoded hex colors** from `DevtailTokens`
- Use **system semantic colors** (`Color.primary`, `.secondary`, `.tertiary`, `Color(.windowBackgroundColor)`, etc.) for automatic light/dark adaptation
- **Asset Catalog** color sets for custom Devtail colors (accent green, accent orange, project colors) with Any/Dark appearance variants
- Theme follows system automatically — no manual toggle

### Liquid Glass

Applied to interactive surfaces:

| Surface | Glass Effect |
|---------|-------------|
| Popover accordion cards | `.glassEffect()` |
| Dashboard sidebar items | `.glassEffect(.regular.interactive())` |
| Dashboard pane cards | `.glassEffect()` |
| Dashboard quick link cards | `.glassEffect()` |
| Launch button | `.glassEffect(.regular.interactive())` with green tint |
| Selected layout thumbnail | glass effect with border tint |

Wrapped in `GlassEffectContainer` when multiple glass elements are adjacent.

**NOT glass** (to avoid overuse):
- Text and labels
- Small badges/pills (branch, environment, stack)
- Separators/dividers
- Layout assignment preview canvas

### Typography

| Token | Font | Size | Weight | Usage |
|-------|------|------|--------|-------|
| `projectTitle` | SF Pro | 18pt | semibold | Project name in detail header |
| `body` | SF Pro | 14pt | regular | General text |
| `bodySemibold` | SF Pro | 14pt | semibold | Pane labels, accordion headers |
| `caption` | SF Pro | 12pt | regular | Guide text, subtexts |
| `captionSmall` | SF Pro | 10pt | regular | Section headers, badges |
| `mono` | Ubuntu Mono | 13pt | regular | Paths, commands, cwd |
| `monoSmall` | Ubuntu Mono | 11pt | regular | Paths in compact contexts |

Ubuntu Mono bundled in app. License file included in Resources.

### Spacing

| Token | Value | Usage |
|-------|-------|-------|
| `gapSmall` | 4pt | Micro spacing |
| `gapMedium` | 8pt | Intra-component |
| `gapLarge` | 14pt | Card internal padding |
| `gapSection` | 24pt | Between dashboard sections |
| `gapSectionTitle` | 6pt | Between section header and guide text |
| `popoverPadding` | 16pt | Popover horizontal padding |

### Sizes

| Token | Value | Usage |
|-------|-------|-------|
| `popoverWidth` | 360pt | Popover width |
| `layoutThumbnailSize` | 100x65 | Dashboard layout thumbnails |
| `layoutPreviewSize` | 400x200 | Dashboard assignment preview |
| `actionButtonSize` | 28pt | Edit/delete button hit target |
| `launchButtonHeight` | 36pt | Launch button |
| `sidebarWidth` | 260pt | Dashboard sidebar |

### Tooltips

| Button | Tooltip |
|--------|---------|
| Launch | "Launch workspace in Ghostty" |
| + (add pane) | "Add a new terminal pane" |
| + (add project) | "Create a new project" |
| ✎ (edit pane) | "Edit pane settings" |
| 🗑 (delete pane) | "Remove this pane" |
| Configure in Dashboard... | "Open full dashboard to configure this workspace" |
| ✎ Edit (project header) | "Edit project name, color, and path" |
| Layout thumbnails | Layout name ("Full", "Halves", "Main + Side", "Quarters") |

---

## Part 6: Structural Changes Summary

### New Files

- `WorkspaceActivityMonitor.swift` — `@Observable` service tracking active workspaces via AppleScript + NSWorkspace notifications
- Asset Catalog color sets — migrated from hardcoded hex, with light/dark variants
- Ubuntu Mono font files in Resources + license file

### Views — Radical Rewrite

- `MenuBarRootView.swift` — split layout → single-column accordion
- `DetailPanel.swift` — tabs → vertical scroll view with sections
- `WorkspacePanel.swift` — redistributed: header hero + layout section + panes section + quick links, generous spacing, guide texts
- `WorkspacePaneRow.swift` — compressed row → spacious card with always-visible actions
- `DashboardRootView.swift` — sidebar with presence (260pt, accent strip, subtitle)

### Views — Moderate Refactor

- `DevtailTokens.swift` — remove hardcoded hex, add new spacing/sizing tokens, Ubuntu Mono typography
- `WorkspaceLayoutPicker.swift` — larger thumbnails (100x65), names below
- `WorkspaceLayoutThumbnail.swift` — larger preview (400x200) in dashboard
- `ProjectRowView.swift` — absorbed into popover accordion, may be removed

### Views — Removed

- `TabHeader.swift` — no more tabs in dashboard

### Configuration Changes

- Deployment target: macOS 15 → macOS 26
- Info.plist: add `ATSApplicationFontsPath` for Ubuntu Mono
- Entitlements: no changes needed

### NOT Touched

- Data models (`Project`, `WorkspacePane`, `WorkspaceLayout`) — data layer intact
- `ProjectStore` — business logic unchanged, only `WorkspaceActivityMonitor` added
- `WorkspaceLauncher` — launch logic unchanged, monitor notified after launch
- Quick Links functionality — visual adaptation only
