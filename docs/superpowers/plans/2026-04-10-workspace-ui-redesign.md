# Workspace UI Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the workspace UI into "Two Worlds" — a lean accordion popover for launching and a rich dashboard for configuring — with Liquid Glass, system theming, Ubuntu Mono, activity detection, guide texts, and tooltips.

**Architecture:** The popover becomes a single-column accordion (no split layout). The dashboard keeps NavigationSplitView but with a wider sidebar and scrollable detail sections (no tabs). A new `WorkspaceActivityMonitor` detects active workspaces via AppleScript. Design tokens migrate from hardcoded hex to system semantic colors + Asset Catalog.

**Tech Stack:** SwiftUI (macOS 26 Tahoe), SwiftData, Liquid Glass (`.glassEffect()`), SF Symbols, Ubuntu Mono (bundled), AppleScript (Ghostty workspace detection)

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `Devtail/DesignSystem/FlowLayout.swift` | Custom `Layout` for wrapping horizontal chips in popover |
| `Devtail/DesignSystem/SectionHeader.swift` | Reusable section header with guide text and info icon |
| `Devtail/Features/ContextSwitcher/Views/Components/PopoverAccordionItem.swift` | Single project accordion row (collapsed + expanded states) |
| `Devtail/Features/ContextSwitcher/Views/Components/PaneChip.swift` | Compact pane pill for popover (label + branch) |
| `Devtail/Features/ContextSwitcher/Views/Components/PaneCard.swift` | Spacious pane card for dashboard (replaces WorkspacePaneRow) |
| `Devtail/Features/ContextSwitcher/Views/Components/DashboardDetailView.swift` | Scrollable detail with hero header + layout + panes + quick links sections |
| `Devtail/Features/ContextSwitcher/Views/Components/DashboardSidebarItem.swift` | Project row for dashboard sidebar with accent strip |
| `Devtail/Features/ContextSwitcher/Views/Components/ActivityDot.swift` | Green dot overlay composable on top of ColorDot |
| `Devtail/Features/ContextSwitcher/Services/WorkspaceActivityMonitor.swift` | `@Observable` service: tracks active workspaces via AppleScript + NSWorkspace |
| `Devtail/Resources/Fonts/UbuntuMono-Regular.ttf` | Bundled font file |
| `Devtail/Resources/Fonts/UbuntuMono-Bold.ttf` | Bundled font file |
| `Devtail/Resources/Fonts/LICENSE-UbuntuMono.txt` | Ubuntu Font Licence |
| `Devtail/Assets.xcassets/Colors/AccentGreen.colorset/Contents.json` | Accent green with light/dark variants |
| `Devtail/Assets.xcassets/Colors/AccentOrange.colorset/Contents.json` | Accent orange with light/dark variants |

### Modified Files
| File | What Changes |
|------|-------------|
| `Devtail/DesignSystem/DevtailTokens.swift` | Remove hardcoded hex, add new tokens, Ubuntu Mono typography |
| `Devtail/Features/ContextSwitcher/Views/MenuBarRootView.swift` | Full rewrite: split → accordion |
| `Devtail/Features/ContextSwitcher/Views/DashboardRootView.swift` | Sidebar refactor + detail routing to new DashboardDetailView |
| `Devtail/Features/ContextSwitcher/Views/Components/WorkspaceLayoutPicker.swift` | Larger thumbnails (100x65), names below, tooltips |
| `Devtail/Features/ContextSwitcher/Views/Components/WorkspaceLayoutThumbnail.swift` | Larger preview, system colors for fill |
| `Devtail/Features/ContextSwitcher/Views/Components/WorkspacePanel.swift` | Refactor: remove layout section (moves to DashboardDetailView) |
| `Devtail/Features/ContextSwitcher/Views/Components/ColorDot.swift` | Add activity dot overlay support |
| `Devtail/Features/ContextSwitcher/Stores/ProjectStore.swift` | Notify WorkspaceActivityMonitor after launch |
| `Devtail/App/DevtailApp.swift` | Create + inject WorkspaceActivityMonitor, update popover width |
| `Devtail/Features/ContextSwitcher/Models/ProjectColor.swift` | Map to Asset Catalog colors instead of hardcoded |

### Removed Files
| File | Reason |
|------|--------|
| `Devtail/Features/ContextSwitcher/Views/Components/DetailPanel.swift` | No more tabs in popover — absorbed into accordion |
| `Devtail/Features/ContextSwitcher/Views/Components/WorkspacePaneRow.swift` | Replaced by PaneCard (dashboard) and PaneChip (popover) |
| `Devtail/Features/ContextSwitcher/Views/Components/TabHeader.swift` | Module tabs move to dashboard sidebar, not popover |

### Config Changes
| Change | Details |
|--------|---------|
| `MACOSX_DEPLOYMENT_TARGET` | `15.0` → `26.0` |
| Info.plist (generated) | Add `ATSApplicationFontsPath = "Fonts"` |

---

## Phase 1: Foundation (Design System + Config)

### Task 1: Update deployment target to macOS 26

**Files:**
- Modify: `Devtail.xcodeproj/project.pbxproj` (build settings)

- [ ] **Step 1: Update deployment target via xcodebuild**

```bash
cd /Volumes/Datos/Frelancer/DEVTAIL/Devtail
# Update MACOSX_DEPLOYMENT_TARGET in project.pbxproj
sd 'MACOSX_DEPLOYMENT_TARGET = 15.0' 'MACOSX_DEPLOYMENT_TARGET = 26.0' Devtail.xcodeproj/project.pbxproj
```

Verify with:
```bash
rg 'MACOSX_DEPLOYMENT_TARGET' Devtail.xcodeproj/project.pbxproj
```
Expected: all lines show `26.0`, no `15.0` remaining.

- [ ] **Step 2: Commit**

```bash
git add Devtail.xcodeproj/project.pbxproj
git commit -m "chore: update deployment target to macOS 26 Tahoe"
```

---

### Task 2: Bundle Ubuntu Mono font

**Files:**
- Create: `Devtail/Resources/Fonts/UbuntuMono-Regular.ttf`
- Create: `Devtail/Resources/Fonts/UbuntuMono-Bold.ttf`
- Create: `Devtail/Resources/Fonts/LICENSE-UbuntuMono.txt`
- Modify: `Devtail.xcodeproj/project.pbxproj` (add ATSApplicationFontsPath)

- [ ] **Step 1: Download Ubuntu Mono from Google Fonts**

```bash
cd /Volumes/Datos/Frelancer/DEVTAIL/Devtail
mkdir -p Devtail/Resources/Fonts
curl -L "https://github.com/google/fonts/raw/main/ufl/ubuntumono/UbuntuMono-Regular.ttf" -o Devtail/Resources/Fonts/UbuntuMono-Regular.ttf
curl -L "https://github.com/google/fonts/raw/main/ufl/ubuntumono/UbuntuMono-Bold.ttf" -o Devtail/Resources/Fonts/UbuntuMono-Bold.ttf
```

- [ ] **Step 2: Add Ubuntu Font Licence**

Create `Devtail/Resources/Fonts/LICENSE-UbuntuMono.txt` with the Ubuntu Font Licence text. Fetch from canonical source:

```bash
curl -L "https://launchpad.net/ubuntu-font-family/trunk/release-0.83/+download/ubuntu-font-family-0.83.zip" -o /tmp/ubuntu-font.zip 2>/dev/null || echo "Manual download needed"
```

If curl fails, create the file manually with the licence text from https://canonical.com/legal/font-licence.

- [ ] **Step 3: Add ATSApplicationFontsPath to build settings**

Since the project uses `GENERATE_INFOPLIST_FILE = YES`, add the plist key via build settings:

```bash
# Add INFOPLIST_KEY_ATSApplicationFontsPath to both Debug and Release
# This tells macOS where to find bundled fonts relative to Resources
sd '(INFOPLIST_KEY_NSAppleEventsUsageDescription)' 'INFOPLIST_KEY_ATSApplicationFontsPath = Fonts;\n\t\t\t\t$1' Devtail.xcodeproj/project.pbxproj
```

Verify:
```bash
rg 'ATSApplicationFontsPath' Devtail.xcodeproj/project.pbxproj
```

- [ ] **Step 4: Commit**

```bash
git add Devtail/Resources/Fonts/ Devtail.xcodeproj/project.pbxproj
git commit -m "chore: bundle Ubuntu Mono font with licence"
```

---

### Task 3: Create Asset Catalog color sets

**Files:**
- Create: `Devtail/Assets.xcassets/Colors/AccentGreen.colorset/Contents.json`
- Create: `Devtail/Assets.xcassets/Colors/AccentOrange.colorset/Contents.json`
- Create: `Devtail/Assets.xcassets/Colors/ProjectGreen.colorset/Contents.json`
- Create: `Devtail/Assets.xcassets/Colors/ProjectBlue.colorset/Contents.json`
- Create: `Devtail/Assets.xcassets/Colors/ProjectOrange.colorset/Contents.json`
- Create: `Devtail/Assets.xcassets/Colors/ProjectPurple.colorset/Contents.json`
- Create: `Devtail/Assets.xcassets/Colors/ProjectPink.colorset/Contents.json`
- Create: `Devtail/Assets.xcassets/Colors/ProjectAmber.colorset/Contents.json`
- Create: `Devtail/Assets.xcassets/Colors/ProjectGray.colorset/Contents.json`

Each color set needs `Any Appearance` and `Dark Appearance` variants. The dark values match current hex. Light values are adjusted for readability on white backgrounds.

- [ ] **Step 1: Create AccentGreen color set**

Create `Devtail/Assets.xcassets/Colors/AccentGreen.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "red" : "0.082",
          "green" : "0.557",
          "blue" : "0.412",
          "alpha" : "1.000"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "red" : "0.114",
          "green" : "0.620",
          "blue" : "0.459",
          "alpha" : "1.000"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 2: Create AccentOrange color set**

Create `Devtail/Assets.xcassets/Colors/AccentOrange.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "red" : "0.850",
          "green" : "0.530",
          "blue" : "0.080",
          "alpha" : "1.000"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "red" : "0.937",
          "green" : "0.624",
          "blue" : "0.153",
          "alpha" : "1.000"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 3: Create all 7 project color sets**

Create one color set per project color. Each needs a slightly darker version for light mode. Pattern for each — example `ProjectGreen.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "red" : "0.082",
          "green" : "0.557",
          "blue" : "0.412",
          "alpha" : "1.000"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "red" : "0.114",
          "green" : "0.620",
          "blue" : "0.459",
          "alpha" : "1.000"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Repeat for ProjectBlue, ProjectOrange, ProjectPurple, ProjectPink, ProjectAmber, ProjectGray with these dark-mode RGB values (existing hex):
- Blue: `0.216, 0.541, 0.867`
- Orange: `0.847, 0.353, 0.188`
- Purple: `0.498, 0.467, 0.867`
- Pink: `0.831, 0.325, 0.494`
- Amber: `0.729, 0.459, 0.090`
- Gray: `0.533, 0.529, 0.502`

Light-mode values: reduce brightness by ~10-15% for good contrast on white backgrounds.

- [ ] **Step 4: Commit**

```bash
git add Devtail/Assets.xcassets/Colors/
git commit -m "feat(design-system): add Asset Catalog color sets with light/dark variants"
```

---

### Task 4: Rewrite DevtailTokens.swift

**Files:**
- Modify: `Devtail/DesignSystem/DevtailTokens.swift` (full rewrite)

- [ ] **Step 1: Rewrite DevtailTokens with system colors + new tokens**

Replace the entire `DevtailTokens.swift` content. Key changes:
- Colors section: replace ALL hardcoded `Color(red:green:blue:)` with `Color("AssetName")` for custom colors and system semantic colors (`Color.primary`, `.secondary`, etc.) for UI colors
- Typography: add `mono` and `monoSmall` using `Font.custom("UbuntuMono-Regular", size:)`, add `projectTitle` at 18pt semibold
- Spacing: update `gapLarge` to 14, `gapSection` to 24, add `gapSectionTitle` at 6, `popoverPadding` to 16
- Sizes: `popoverWidth` to 360, remove `detailPanelHeight`, add `layoutThumbnailWidth/Height` (100/65), `layoutPreviewWidth/Height` (400/200), `actionButtonSize` (28), `launchButtonHeight` (36), `sidebarWidth` (260)

```swift
import SwiftUI

enum DevtailTokens {

    // MARK: - Colors

    enum Colors {
        // === Semantic (system-provided, auto light/dark) ===
        static let textPrimary          = Color.primary
        static let textSecondary        = Color.secondary
        static let textTertiary         = Color(nsColor: .tertiaryLabelColor)
        static let textMuted            = Color(nsColor: .quaternaryLabelColor)
        static let textPlaceholder      = Color(nsColor: .placeholderTextColor)
        static let textDisabled         = Color(nsColor: .disabledControlTextColor)

        // === Backgrounds (system-provided) ===
        static let appBackground        = Color(nsColor: .windowBackgroundColor)
        static let popoverBackground    = Color(nsColor: .controlBackgroundColor)
        static let cardBackground       = Color(nsColor: .controlBackgroundColor)
        static let inputBackground      = Color(nsColor: .textBackgroundColor)
        static let sidebar              = Color(nsColor: .windowBackgroundColor)
        static let hoverState           = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)

        // === Borders (system-provided) ===
        static let borderSubtle         = Color(nsColor: .separatorColor)
        static let borderPrimary        = Color(nsColor: .gridColor)

        // === Custom Accents (Asset Catalog) ===
        static let accentGreen          = Color("AccentGreen")
        static let accentOrange         = Color("AccentOrange")

        // === Project Colors (Asset Catalog) ===
        static let projectGreen         = Color("ProjectGreen")
        static let projectBlue          = Color("ProjectBlue")
        static let projectOrange        = Color("ProjectOrange")
        static let projectPurple        = Color("ProjectPurple")
        static let projectPink          = Color("ProjectPink")
        static let projectAmber         = Color("ProjectAmber")
        static let projectGray          = Color("ProjectGray")

        // === Menu Bar Icon ===
        static let menuBarIconBg        = Color("AccentGreen")
        static let menuBarIconText      = Color.white

        // === Activity ===
        static let activityGreen        = Color.green
    }

    // MARK: - Typography

    enum Typography {
        // === Titles ===
        static let projectTitle         = Font.system(size: 18, weight: .semibold)
        static let titleLarge           = Font.system(size: 18, weight: .medium)
        static let titleMedium          = Font.system(size: 14, weight: .medium)

        // === Body ===
        static let body                 = Font.system(size: 14)
        static let bodySemibold         = Font.system(size: 14, weight: .semibold)
        static let bodySmall            = Font.system(size: 12)
        static let caption              = Font.system(size: 12)
        static let captionSmall         = Font.system(size: 10)

        // === Monospace (Ubuntu Mono) ===
        static let mono                 = Font.custom("UbuntuMono-Regular", size: 13)
        static let monoSmall            = Font.custom("UbuntuMono-Regular", size: 11)
        static let monoBold             = Font.custom("UbuntuMono-Bold", size: 13)
    }

    // MARK: - Spacing

    enum Spacing {
        static let popoverPadding: CGFloat       = 16
        static let dashboardPadding: CGFloat     = 24
        static let cardPadding: CGFloat          = 14
        static let sidebarItemPadding: CGFloat   = 14
        static let sidebarItemVertical: CGFloat  = 12

        static let gapTiny: CGFloat              = 2
        static let gapSmall: CGFloat             = 4
        static let gapMedium: CGFloat            = 8
        static let gapDefault: CGFloat           = 10
        static let gapLarge: CGFloat             = 14
        static let gapSection: CGFloat           = 24
        static let gapSectionTitle: CGFloat      = 6
        static let gapXLarge: CGFloat            = 20

        static let sectionBottom: CGFloat        = 20
        static let headerBottom: CGFloat         = 12
        static let sectionTitleBottom: CGFloat   = 6
        static let searchVertical: CGFloat       = 8
    }

    // MARK: - Sizes

    enum Sizes {
        // === Popover ===
        static let popoverWidth: CGFloat         = 360
        static let popoverMaxHeight: CGFloat     = 480

        // === Dashboard ===
        static let dashboardWidth: CGFloat       = 900
        static let dashboardHeight: CGFloat      = 600
        static let sidebarWidth: CGFloat         = 260

        // === Layout ===
        static let layoutThumbnailWidth: CGFloat = 100
        static let layoutThumbnailHeight: CGFloat = 65
        static let layoutPreviewWidth: CGFloat   = 400
        static let layoutPreviewHeight: CGFloat  = 200

        // === Buttons ===
        static let launchButtonHeight: CGFloat   = 36
        static let actionButtonSize: CGFloat     = 28

        // === Dots ===
        static let projectDot: CGFloat           = 8
        static let projectDotLarge: CGFloat      = 14
        static let activityDotSize: CGFloat      = 8
    }

    // MARK: - Corner Radius

    enum Radius {
        static let badge: CGFloat                = 3
        static let pill: CGFloat                 = 4
        static let chip: CGFloat                 = 6
        static let card: CGFloat                 = 8
        static let popover: CGFloat              = 10
        static let window: CGFloat               = 12
    }

    // MARK: - Border Width

    enum BorderWidth {
        static let `default`: CGFloat            = 0.5
        static let accentStrip: CGFloat          = 3
    }

    // MARK: - Active States

    enum ActiveState {
        static let activeBgOpacity: Double       = 0.094
        static let activeBorderOpacity: Double   = 0.251
        static let badgeBgOpacity: Double        = 0.125
    }
}

extension Color {
    static var activeProjectBg: Color {
        DevtailTokens.Colors.accentGreen.opacity(DevtailTokens.ActiveState.activeBgOpacity)
    }
    static var activeProjectBorder: Color {
        DevtailTokens.Colors.accentGreen.opacity(DevtailTokens.ActiveState.activeBorderOpacity)
    }
}
```

- [ ] **Step 2: Update ProjectColor to use Asset Catalog colors**

In `Devtail/Features/ContextSwitcher/Models/ProjectColor.swift`, change each case's `color` computed property from `DevtailTokens.Colors.projectGreen` (which used to be hardcoded hex, now is `Color("ProjectGreen")`). Since `DevtailTokens.Colors.projectGreen` already points to the asset catalog after Task 4 Step 1, **no change needed** — the mapping is already correct. Verify the mapping compiles.

- [ ] **Step 3: Commit**

```bash
git add Devtail/DesignSystem/DevtailTokens.swift
git commit -m "feat(design-system): migrate to system colors, Asset Catalog, Ubuntu Mono typography"
```

---

### Task 5: Create FlowLayout

**Files:**
- Create: `Devtail/DesignSystem/FlowLayout.swift`

- [ ] **Step 1: Implement FlowLayout using Layout protocol**

```swift
import SwiftUI

/// A layout that arranges subviews horizontally, wrapping to the next line
/// when the available width is exceeded. Used for pane chips in the popover.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return ArrangeResult(
            size: CGSize(width: totalWidth, height: currentY + lineHeight),
            positions: positions
        )
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Devtail/DesignSystem/FlowLayout.swift
git commit -m "feat(design-system): add FlowLayout for wrapping horizontal chips"
```

---

### Task 6: Create SectionHeader component

**Files:**
- Create: `Devtail/DesignSystem/SectionHeader.swift`

- [ ] **Step 1: Implement reusable section header with guide text**

```swift
import SwiftUI

/// Reusable section header with title and guide text.
/// Used across dashboard sections for consistent visual hierarchy.
///
/// Usage:
///     SectionHeader(title: "LAYOUT", guide: "Choose how your terminal panes are arranged.")
struct SectionHeader: View {
    let title: String
    var guide: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSectionTitle) {
            Text(title)
                .font(DevtailTokens.Typography.captionSmall)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
                .tracking(0.5)

            if let guide {
                Label(guide, systemImage: "info.circle")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Devtail/DesignSystem/SectionHeader.swift
git commit -m "feat(design-system): add SectionHeader with guide text and info icon"
```

---

## Phase 2: Activity Detection

### Task 7: Create WorkspaceActivityMonitor

**Files:**
- Create: `Devtail/Features/ContextSwitcher/Services/WorkspaceActivityMonitor.swift`

- [ ] **Step 1: Implement the monitor service**

```swift
import SwiftUI
import SwiftData

/// Tracks which projects have active Ghostty workspaces.
///
/// Detection strategy:
/// 1. On launch: project ID added to `launchedProjectPaths`
/// 2. On popover open / manual refresh: AppleScript checks working directories
/// 3. NSWorkspace notification: if Ghostty terminates, clear everything
@MainActor @Observable
final class WorkspaceActivityMonitor {

    /// Project IDs with confirmed active workspaces.
    private(set) var activeProjectIDs: Set<UUID> = []

    /// Maps project ID → directory path for projects launched this session.
    private var launchedProjectPaths: [UUID: String] = [:]

    private let ghosttyBundleID = "com.mitchellh.ghostty"

    init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == self?.ghosttyBundleID else { return }
            Task { @MainActor in
                self?.activeProjectIDs.removeAll()
                self?.launchedProjectPaths.removeAll()
            }
        }
    }

    /// Call after successfully launching a workspace.
    func markLaunched(projectID: UUID, directoryPath: String) {
        launchedProjectPaths[projectID] = directoryPath
        activeProjectIDs.insert(projectID)
    }

    /// Refresh activity state for all launched projects.
    /// Call when popover opens or on demand.
    func refresh() async {
        guard !launchedProjectPaths.isEmpty else { return }
        guard isGhosttyRunning() else {
            activeProjectIDs.removeAll()
            launchedProjectPaths.removeAll()
            return
        }

        var stillActive: Set<UUID> = []
        for (projectID, path) in launchedProjectPaths {
            if await checkWorkspaceActive(directoryPath: path) {
                stillActive.insert(projectID)
            }
        }
        activeProjectIDs = stillActive

        // Clean up paths for projects no longer active
        for id in launchedProjectPaths.keys where !stillActive.contains(id) {
            launchedProjectPaths.removeValue(forKey: id)
        }
    }

    func isActive(projectID: UUID) -> Bool {
        activeProjectIDs.contains(projectID)
    }

    // MARK: - Private

    private func isGhosttyRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == ghosttyBundleID
        }
    }

    private func checkWorkspaceActive(directoryPath: String) async -> Bool {
        let script = buildCheckScript(directoryPath: directoryPath)
        return await Task.detached {
            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?
            let result = appleScript?.executeAndReturnError(&error)
            guard error == nil else { return false }
            return result?.booleanValue ?? false
        }.value
    }

    private func buildCheckScript(directoryPath: String) -> String {
        let escaped = directoryPath.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        tell application "Ghostty"
            if not running then return false
            set matchRoot to "\(escaped)/"
            repeat with tm in every terminal
                set cwd to working directory of tm
                if cwd = "\(escaped)" then return true
                if cwd starts with matchRoot then return true
            end repeat
            return false
        end tell
        """
    }
}
```

- [ ] **Step 2: Wire into DevtailApp**

In `Devtail/App/DevtailApp.swift`, add `WorkspaceActivityMonitor` as a `@State` property and inject it into the environment:

Add after the `projectStore` property:
```swift
@State private var activityMonitor = WorkspaceActivityMonitor()
```

Add `.environment(activityMonitor)` to both the `MenuBarExtra` and `WindowGroup` scenes, right after `.environment(projectStore)`.

- [ ] **Step 3: Notify monitor after launch in ProjectStore**

In `Devtail/Features/ContextSwitcher/Stores/ProjectStore.swift`, the `launchWorkspace(for:)` method needs to notify the monitor. However, ProjectStore doesn't have a reference to the monitor. Instead, we'll have the view call `monitor.markLaunched(...)` after a successful launch.

This will be wired in the view layer (Task 11 / Task 13) where both `ProjectStore` and `WorkspaceActivityMonitor` are available via `@Environment`.

- [ ] **Step 4: Commit**

```bash
git add Devtail/Features/ContextSwitcher/Services/WorkspaceActivityMonitor.swift Devtail/App/DevtailApp.swift
git commit -m "feat(activity): add WorkspaceActivityMonitor with AppleScript detection"
```

---

### Task 8: Create ActivityDot component

**Files:**
- Create: `Devtail/Features/ContextSwitcher/Views/Components/ActivityDot.swift`

- [ ] **Step 1: Implement activity dot overlay**

```swift
import SwiftUI

/// Green dot indicator for active workspaces.
/// Designed to overlay on top of a ColorDot.
///
/// Usage:
///     ColorDot(color: project.color)
///         .overlay(alignment: .bottomTrailing) {
///             ActivityDot(isActive: monitor.isActive(projectID: project.id))
///         }
struct ActivityDot: View {
    let isActive: Bool

    var body: some View {
        if isActive {
            Circle()
                .fill(DevtailTokens.Colors.activityGreen)
                .frame(
                    width: DevtailTokens.Sizes.activityDotSize,
                    height: DevtailTokens.Sizes.activityDotSize
                )
                .overlay {
                    Circle()
                        .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5)
                }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Devtail/Features/ContextSwitcher/Views/Components/ActivityDot.swift
git commit -m "feat(activity): add ActivityDot green indicator component"
```

---

## Phase 3: Popover Rewrite

### Task 9: Create PaneChip component

**Files:**
- Create: `Devtail/Features/ContextSwitcher/Views/Components/PaneChip.swift`

- [ ] **Step 1: Implement pane chip for popover**

```swift
import SwiftUI

/// Compact pane pill for the popover accordion.
/// Shows label + optional branch in a small chip.
struct PaneChip: View {
    let label: String
    var branch: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
            Text(label)
                .font(DevtailTokens.Typography.captionSmall)
                .fontWeight(.semibold)
                .foregroundStyle(DevtailTokens.Colors.textPrimary)
                .lineLimit(1)

            if let branch {
                Label(branch, systemImage: "arrow.triangle.branch")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
        .glassEffect()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Devtail/Features/ContextSwitcher/Views/Components/PaneChip.swift
git commit -m "feat(popover): add PaneChip compact component"
```

---

### Task 10: Create PopoverAccordionItem component

**Files:**
- Create: `Devtail/Features/ContextSwitcher/Views/Components/PopoverAccordionItem.swift`

- [ ] **Step 1: Implement accordion item with collapsed/expanded states**

```swift
import SwiftUI

/// Single project row in the popover accordion.
/// Collapsed: color dot + name + pane count + chevron
/// Expanded: + pane chips + Launch button + Configure link
struct PopoverAccordionItem: View {
    let project: Project
    let isExpanded: Bool
    let isActive: Bool
    let branches: [UUID: String] // paneID → branch
    let onToggle: () -> Void
    let onLaunch: () -> Void
    let onOpenDashboard: () -> Void
    var isLaunching: Bool = false

    private var sortedPanes: [WorkspacePane] {
        (project.workspacePanes ?? []).sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // --- Collapsed header (always visible) ---
            Button(action: onToggle) {
                HStack(spacing: DevtailTokens.Spacing.gapMedium) {
                    ColorDot(color: project.color, size: DevtailTokens.Sizes.projectDot)
                        .overlay(alignment: .bottomTrailing) {
                            ActivityDot(isActive: isActive)
                        }

                    Text(project.name)
                        .font(DevtailTokens.Typography.bodySemibold)
                        .foregroundStyle(DevtailTokens.Colors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(sortedPanes.count) panes")
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                }
                .padding(.horizontal, DevtailTokens.Spacing.cardPadding)
                .padding(.vertical, DevtailTokens.Spacing.sidebarItemVertical)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // --- Expanded content ---
            if isExpanded {
                VStack(spacing: DevtailTokens.Spacing.gapLarge) {
                    // Pane chips in flow layout
                    if !sortedPanes.isEmpty {
                        FlowLayout(spacing: DevtailTokens.Spacing.gapMedium) {
                            ForEach(sortedPanes) { pane in
                                PaneChip(
                                    label: pane.label,
                                    branch: branches[pane.id]
                                )
                            }
                        }
                    }

                    // Launch button
                    Button(action: onLaunch) {
                        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                            Image(systemName: isLaunching ? "hourglass" : "play.fill")
                            Text(isLaunching ? "Launching..." : "Launch")
                        }
                        .font(DevtailTokens.Typography.bodySemibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: DevtailTokens.Sizes.launchButtonHeight)
                        .background(DevtailTokens.Colors.accentGreen)
                        .clipShape(RoundedRectangle(cornerRadius: DevtailTokens.Radius.card))
                        .glassEffect(.regular.interactive())
                    }
                    .buttonStyle(.plain)
                    .disabled(isLaunching || sortedPanes.isEmpty || project.directoryPath.isEmpty)
                    .help("Launch workspace in Ghostty")

                    // Configure link
                    Button(action: onOpenDashboard) {
                        Text("Configure in Dashboard...")
                            .font(DevtailTokens.Typography.caption)
                            .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Open full dashboard to configure this workspace")
                }
                .padding(.horizontal, DevtailTokens.Spacing.cardPadding)
                .padding(.bottom, DevtailTokens.Spacing.cardPadding)
            }
        }
        .glassEffect()
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Devtail/Features/ContextSwitcher/Views/Components/PopoverAccordionItem.swift
git commit -m "feat(popover): add PopoverAccordionItem with collapsed/expanded states"
```

---

### Task 11: Rewrite MenuBarRootView

**Files:**
- Modify: `Devtail/Features/ContextSwitcher/Views/MenuBarRootView.swift` (full rewrite)

- [ ] **Step 1: Rewrite to single-column accordion**

Replace the entire body of `MenuBarRootView.swift`. The new structure:
- Search bar at top
- Accordion list of projects (exclusive expand)
- Footer with Manage/Settings/Quit

Key changes:
- Remove `DetailPanel` usage entirely
- Remove `selectedTab` state
- Remove the split between project list and detail panel
- Add `@Environment(WorkspaceActivityMonitor.self) private var activityMonitor`
- Add `@State private var expandedProjectID: UUID? = nil` for accordion
- Add `GitBranchDetector` for branch resolution
- On popover appear (`.onAppear`), call `activityMonitor.refresh()`
- On Launch, after `store.launchWorkspace(for:)`, call `activityMonitor.markLaunched(projectID:directoryPath:)`
- Width becomes `DevtailTokens.Sizes.popoverWidth` (360)
- Remove `.frame(height:)` on project list — let it grow naturally
- Wrap accordion items in a `ScrollView` with max height `DevtailTokens.Sizes.popoverMaxHeight`

```swift
struct MenuBarRootView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(WorkspaceActivityMonitor.self) private var activityMonitor
    @Environment(\.openWindow) private var openWindow

    @State private var searchQuery: String = ""
    @State private var expandedProjectID: UUID? = nil
    @State private var keyboardSelectedIndex: Int? = nil

    private let filterEngine = ProjectFilterEngine()
    private let branchDetector = GitBranchDetector()

    var body: some View {
        VStack(spacing: 0) {
            // Search
            if !store.projects.isEmpty {
                SearchField(text: $searchQuery)
                    .padding(.horizontal, DevtailTokens.Spacing.popoverPadding)
                    .padding(.top, DevtailTokens.Spacing.popoverPadding)
            }

            // Content
            if store.projects.isEmpty {
                EmptyProjectsView(onCreate: openDashboardForCreate)
                    .padding(DevtailTokens.Spacing.popoverPadding)
            } else if filteredProjects.isEmpty {
                noSearchResultsView
            } else {
                ScrollView {
                    LazyVStack(spacing: DevtailTokens.Spacing.gapMedium) {
                        ForEach(filteredProjects) { project in
                            PopoverAccordionItem(
                                project: project,
                                isExpanded: expandedProjectID == project.id,
                                isActive: activityMonitor.isActive(projectID: project.id),
                                branches: resolveBranches(for: project),
                                onToggle: { toggleExpand(project.id) },
                                onLaunch: { launchWorkspace(for: project) },
                                onOpenDashboard: { openDashboardForProject(project.id) },
                                isLaunching: store.isLaunchingWorkspace
                            )
                        }
                    }
                    .padding(DevtailTokens.Spacing.popoverPadding)
                }
            }

            Divider()

            // Footer
            HStack(spacing: DevtailTokens.Spacing.gapLarge) {
                Button { openDashboard() } label: {
                    Label("Manage…", systemImage: "square.grid.2x2")
                        .font(DevtailTokens.Typography.bodySmall)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
                .help("Open the Devtail dashboard")

                Spacer()

                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
                    .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal, DevtailTokens.Spacing.popoverPadding)
            .padding(.vertical, DevtailTokens.Spacing.gapMedium)

            // New project link
            Button { openDashboardForCreate() } label: {
                Label("New project", systemImage: "plus")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.accentGreen)
            }
            .buttonStyle(.plain)
            .padding(.bottom, DevtailTokens.Spacing.gapMedium)
            .help("Create a new project")
        }
        .frame(width: DevtailTokens.Sizes.popoverWidth)
        .task { store.loadProjects() }
        .task { await activityMonitor.refresh() }
    }

    // ... helper methods for toggle, launch, branch resolution, navigation
}
```

The full implementation includes:
- `toggleExpand(_:)` — exclusive accordion toggle
- `launchWorkspace(for:)` — calls store, then marks launched in monitor
- `resolveBranches(for:)` — uses branchDetector per pane
- Navigation helpers (openDashboard, openDashboardForCreate, openDashboardForProject)
- Keyboard navigation preserved (up/down/return/escape)
- `noSearchResultsView` preserved

- [ ] **Step 2: Commit**

```bash
git add Devtail/Features/ContextSwitcher/Views/MenuBarRootView.swift
git commit -m "feat(popover): rewrite to single-column accordion layout"
```

---

## Phase 4: Dashboard Rewrite

### Task 12: Create DashboardSidebarItem

**Files:**
- Create: `Devtail/Features/ContextSwitcher/Views/Components/DashboardSidebarItem.swift`

- [ ] **Step 1: Implement sidebar item with accent strip**

```swift
import SwiftUI

/// Project row for the dashboard sidebar.
/// Shows accent color strip, name, layout info, and activity dot.
struct DashboardSidebarItem: View {
    let project: Project
    let isSelected: Bool
    let isActive: Bool

    private var paneCount: Int {
        project.workspacePanes?.count ?? 0
    }

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapMedium) {
            // Accent strip
            RoundedRectangle(cornerRadius: 1.5)
                .fill(project.color.color)
                .frame(width: DevtailTokens.BorderWidth.accentStrip)
                .opacity(isSelected ? 1.0 : 0.5)

            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
                HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                    ColorDot(color: project.color, size: DevtailTokens.Sizes.projectDot)
                        .overlay(alignment: .bottomTrailing) {
                            ActivityDot(isActive: isActive)
                        }

                    Text(project.name)
                        .font(DevtailTokens.Typography.bodySemibold)
                        .foregroundStyle(DevtailTokens.Colors.textPrimary)
                        .lineLimit(1)
                }

                Text("\(project.layout.displayName) · \(paneCount) panes")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, DevtailTokens.Spacing.sidebarItemVertical)
        .padding(.trailing, DevtailTokens.Spacing.sidebarItemPadding)
        .contentShape(Rectangle())
        .glassEffect(.regular.interactive())
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Devtail/Features/ContextSwitcher/Views/Components/DashboardSidebarItem.swift
git commit -m "feat(dashboard): add DashboardSidebarItem with accent strip"
```

---

### Task 13: Create PaneCard component

**Files:**
- Create: `Devtail/Features/ContextSwitcher/Views/Components/PaneCard.swift`

- [ ] **Step 1: Implement spacious pane card for dashboard**

```swift
import SwiftUI

/// Spacious pane card for the dashboard.
/// Shows label, badges, directory, command, and always-visible action buttons.
struct PaneCard: View {
    let pane: WorkspacePane
    var branch: String? = nil
    var slotLabel: String? = nil
    var canDelete: Bool = true
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapMedium) {
            // Line 1: Label + badges
            HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                Text(pane.label)
                    .font(DevtailTokens.Typography.bodySemibold)
                    .foregroundStyle(DevtailTokens.Colors.textPrimary)
                    .lineLimit(1)

                Spacer()

                if let slotLabel {
                    Text(slotLabel)
                        .font(DevtailTokens.Typography.captionSmall)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                        .padding(.horizontal, DevtailTokens.Spacing.gapSmall)
                        .padding(.vertical, 1)
                }

                if let branch {
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .font(DevtailTokens.Typography.captionSmall)
                        .foregroundStyle(DevtailTokens.Colors.accentGreen)
                        .padding(.horizontal, DevtailTokens.Spacing.gapSmall)
                        .padding(.vertical, 1)
                }

                if let stack = pane.stack, !stack.isEmpty {
                    Text(stack)
                        .font(DevtailTokens.Typography.captionSmall)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                        .padding(.horizontal, DevtailTokens.Spacing.gapSmall)
                        .padding(.vertical, 1)
                }

                if let env = pane.environment {
                    EnvironmentPill(environment: env, compact: true)
                }
            }

            // Line 2: Directory
            Text(pane.relativeCwd)
                .font(DevtailTokens.Typography.mono)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
                .lineLimit(1)

            // Line 3: Command (if present)
            if let command = pane.command, !command.isEmpty {
                Text(command)
                    .font(DevtailTokens.Typography.mono)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .lineLimit(1)
            }

            // Actions — always visible
            HStack {
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .frame(
                            width: DevtailTokens.Sizes.actionButtonSize,
                            height: DevtailTokens.Sizes.actionButtonSize
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
                .help("Edit pane settings")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .frame(
                            width: DevtailTokens.Sizes.actionButtonSize,
                            height: DevtailTokens.Sizes.actionButtonSize
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(canDelete ? DevtailTokens.Colors.textSecondary : DevtailTokens.Colors.textDisabled)
                .disabled(!canDelete)
                .help(canDelete ? "Remove this pane" : "Cannot delete the last pane")
            }
        }
        .padding(.horizontal, DevtailTokens.Spacing.cardPadding)
        .padding(.vertical, DevtailTokens.Spacing.gapDefault)
        .glassEffect()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Devtail/Features/ContextSwitcher/Views/Components/PaneCard.swift
git commit -m "feat(dashboard): add PaneCard spacious component with always-visible actions"
```

---

### Task 14: Create DashboardDetailView

**Files:**
- Create: `Devtail/Features/ContextSwitcher/Views/Components/DashboardDetailView.swift`

- [ ] **Step 1: Implement scrollable detail with all sections**

This is the main detail view for the dashboard. It contains:
- Section A: Header hero (project name, path, status, Launch + Edit buttons)
- Section B: Layout (guide text, picker, assignment preview)
- Section C: Panes (guide text, pane cards, add button)
- Section D: Quick Links (guide text, existing QuickLinksPanel adapted)

```swift
import SwiftUI

/// Scrollable detail view for the dashboard.
/// Contains hero header, layout section, panes section, and quick links.
struct DashboardDetailView: View {
    let project: Project
    @Environment(ProjectStore.self) private var store
    @Environment(WorkspaceActivityMonitor.self) private var activityMonitor

    @State private var editingPaneID: UUID? = nil
    @State private var isAddingPane: Bool = false

    private let branchDetector = GitBranchDetector()

    private var sortedPanes: [WorkspacePane] {
        (project.workspacePanes ?? []).sorted { $0.order < $1.order }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSection) {
                heroHeader
                layoutSection
                panesSection
                quickLinksSection
            }
            .padding(DevtailTokens.Spacing.dashboardPadding)
        }
    }

    // MARK: - Section A: Hero Header

    @ViewBuilder
    private var heroHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
                HStack(spacing: DevtailTokens.Spacing.gapMedium) {
                    ColorDot(
                        color: project.color,
                        size: DevtailTokens.Sizes.projectDotLarge
                    )
                    .overlay(alignment: .bottomTrailing) {
                        ActivityDot(isActive: activityMonitor.isActive(projectID: project.id))
                    }

                    Text(project.name)
                        .font(DevtailTokens.Typography.projectTitle)
                        .foregroundStyle(DevtailTokens.Colors.textPrimary)
                }

                if !project.directoryPath.isEmpty {
                    Text(project.directoryPath)
                        .font(DevtailTokens.Typography.mono)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if activityMonitor.isActive(projectID: project.id) {
                    Text("Active")
                        .font(DevtailTokens.Typography.captionSmall)
                        .foregroundStyle(DevtailTokens.Colors.accentGreen)
                        .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
                        .padding(.vertical, DevtailTokens.Spacing.gapTiny)
                        .background(
                            DevtailTokens.Colors.accentGreen.opacity(
                                DevtailTokens.ActiveState.badgeBgOpacity
                            )
                        )
                        .clipShape(Capsule())
                }
            }

            Spacer()

            VStack(spacing: DevtailTokens.Spacing.gapMedium) {
                // Launch button
                Button {
                    launchWorkspace()
                } label: {
                    HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                        Image(systemName: store.isLaunchingWorkspace ? "hourglass" : "play.fill")
                        Text(store.isLaunchingWorkspace ? "Launching..." : "Launch")
                    }
                    .font(DevtailTokens.Typography.bodySemibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DevtailTokens.Spacing.gapXLarge)
                    .frame(height: DevtailTokens.Sizes.launchButtonHeight)
                    .background(DevtailTokens.Colors.accentGreen)
                    .clipShape(RoundedRectangle(cornerRadius: DevtailTokens.Radius.card))
                    .glassEffect(.regular.interactive())
                }
                .buttonStyle(.plain)
                .disabled(store.isLaunchingWorkspace || sortedPanes.isEmpty || project.directoryPath.isEmpty)
                .help("Launch workspace in Ghostty")
            }
        }
    }

    // MARK: - Section B: Layout

    @ViewBuilder
    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapLarge) {
            SectionHeader(
                title: "LAYOUT",
                guide: "Choose how your terminal panes are arranged when you launch this workspace."
            )

            WorkspaceLayoutPicker(
                selected: project.layout,
                onSelect: { layout in
                    store.setLayout(for: project, layout: layout)
                }
            )

            WorkspaceLayoutThumbnail(
                layout: project.layout,
                size: CGSize(
                    width: DevtailTokens.Sizes.layoutPreviewWidth,
                    height: DevtailTokens.Sizes.layoutPreviewHeight
                ),
                slotLabels: slotLabels(for: project),
                onSlotMenu: { slot in
                    slotMenuContent(for: slot)
                }
            )

            SectionHeader(guide: "Assign each pane to a slot. Unassigned panes won't open.")
        }
    }

    // MARK: - Section C: Panes

    @ViewBuilder
    private var panesSection: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapLarge) {
            SectionHeader(
                title: "PANES",
                guide: "Terminal sessions that will open when you launch this workspace."
            )

            if sortedPanes.isEmpty {
                emptyPanesView
            } else {
                GlassEffectContainer {
                    VStack(spacing: DevtailTokens.Spacing.gapMedium) {
                        ForEach(sortedPanes) { pane in
                            if editingPaneID == pane.id {
                                WorkspacePaneEditRow(
                                    projectRoot: project.directoryPath,
                                    existingPane: pane,
                                    onSave: { label, cwd, command, stack, env in
                                        store.updateWorkspacePane(
                                            pane,
                                            label: label,
                                            relativeCwd: cwd,
                                            command: command,
                                            stack: stack,
                                            environment: env
                                        )
                                        editingPaneID = nil
                                    },
                                    onCancel: { editingPaneID = nil }
                                )
                            } else {
                                PaneCard(
                                    pane: pane,
                                    branch: branchDetector.detectBranch(
                                        in: URL(fileURLWithPath: project.directoryPath)
                                            .appendingPathComponent(pane.relativeCwd)
                                    ),
                                    slotLabel: pane.layoutSlot >= 0 ? "Slot \(pane.layoutSlot + 1)" : nil,
                                    canDelete: sortedPanes.count > 1,
                                    onEdit: { editingPaneID = pane.id },
                                    onDelete: { store.deleteWorkspacePane(pane) }
                                )
                            }
                        }
                    }
                }
            }

            if isAddingPane {
                WorkspacePaneEditRow(
                    projectRoot: project.directoryPath,
                    existingPane: nil,
                    onSave: { label, cwd, command, stack, env in
                        store.addWorkspacePane(
                            to: project,
                            label: label,
                            relativeCwd: cwd,
                            command: command,
                            stack: stack,
                            environment: env
                        )
                        isAddingPane = false
                    },
                    onCancel: { isAddingPane = false }
                )
            }

            Button { isAddingPane = true } label: {
                Label("Add pane", systemImage: "plus")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
                    .padding(.horizontal, DevtailTokens.Spacing.gapLarge)
                    .padding(.vertical, DevtailTokens.Spacing.gapMedium)
                    .overlay {
                        RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                            .stroke(DevtailTokens.Colors.borderSubtle, lineWidth: DevtailTokens.BorderWidth.default)
                    }
            }
            .buttonStyle(.plain)
            .help("Add a new terminal pane")
        }
    }

    // MARK: - Section D: Quick Links

    @ViewBuilder
    private var quickLinksSection: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapLarge) {
            SectionHeader(
                title: "QUICK LINKS",
                guide: "Bookmarks to URLs, files, or folders you access frequently for this project."
            )

            QuickLinksPanel(projectID: project.id)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var emptyPanesView: some View {
        VStack(spacing: DevtailTokens.Spacing.gapLarge) {
            Label(
                "No panes yet. Add your first terminal pane to get started.",
                systemImage: "info.circle"
            )
            .font(DevtailTokens.Typography.caption)
            .foregroundStyle(DevtailTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(DevtailTokens.Spacing.gapSection)
    }

    private func slotLabels(for project: Project) -> [Int: String] {
        var labels: [Int: String] = [:]
        for pane in sortedPanes where pane.layoutSlot >= 0 {
            labels[pane.layoutSlot] = pane.label
        }
        return labels
    }

    private func slotMenuContent(for slot: Int) -> some View {
        ForEach(sortedPanes) { pane in
            Button(pane.label) {
                store.assignPaneToSlot(pane: pane, slot: slot)
            }
        }
    }

    private func launchWorkspace() {
        Task {
            await store.launchWorkspace(for: project)
            activityMonitor.markLaunched(
                projectID: project.id,
                directoryPath: project.directoryPath
            )
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Devtail/Features/ContextSwitcher/Views/Components/DashboardDetailView.swift
git commit -m "feat(dashboard): add DashboardDetailView with hero, layout, panes, quick links sections"
```

---

### Task 15: Update WorkspaceLayoutPicker for larger thumbnails

**Files:**
- Modify: `Devtail/Features/ContextSwitcher/Views/Components/WorkspaceLayoutPicker.swift`

- [ ] **Step 1: Update thumbnail size and add labels below**

Rewrite `WorkspaceLayoutPicker.swift`:

```swift
import SwiftUI

struct WorkspaceLayoutPicker: View {
    let selected: WorkspaceLayout
    let onSelect: (WorkspaceLayout) -> Void

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapLarge) {
            ForEach(WorkspaceLayout.allCases, id: \.self) { layout in
                Button { onSelect(layout) } label: {
                    VStack(spacing: DevtailTokens.Spacing.gapSmall) {
                        WorkspaceLayoutThumbnail(
                            layout: layout,
                            size: CGSize(
                                width: DevtailTokens.Sizes.layoutThumbnailWidth,
                                height: DevtailTokens.Sizes.layoutThumbnailHeight
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: DevtailTokens.Radius.chip)
                                .stroke(
                                    selected == layout
                                        ? DevtailTokens.Colors.accentGreen
                                        : DevtailTokens.Colors.borderSubtle,
                                    lineWidth: selected == layout ? 2 : DevtailTokens.BorderWidth.default
                                )
                        }

                        Text(layout.displayName)
                            .font(DevtailTokens.Typography.caption)
                            .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .help(layout.displayName)
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Devtail/Features/ContextSwitcher/Views/Components/WorkspaceLayoutPicker.swift
git commit -m "feat(dashboard): update layout picker with larger thumbnails and labels"
```

---

### Task 16: Update WorkspaceLayoutThumbnail for system colors

**Files:**
- Modify: `Devtail/Features/ContextSwitcher/Views/Components/WorkspaceLayoutThumbnail.swift`

- [ ] **Step 1: Replace hardcoded fill color with system color**

In `WorkspaceLayoutThumbnail.swift`, find the hardcoded fill color in the Canvas:

```swift
// OLD:
Color(red: 0.267, green: 0.267, blue: 0.267)
```

Replace with:
```swift
// NEW:
Color(nsColor: .quaternaryLabelColor)
```

This adapts to light/dark mode automatically.

- [ ] **Step 2: Commit**

```bash
git add Devtail/Features/ContextSwitcher/Views/Components/WorkspaceLayoutThumbnail.swift
git commit -m "refactor(dashboard): use system color for layout thumbnail fill"
```

---

### Task 17: Rewrite DashboardRootView

**Files:**
- Modify: `Devtail/Features/ContextSwitcher/Views/DashboardRootView.swift`

- [ ] **Step 1: Refactor sidebar and detail routing**

The dashboard keeps `NavigationSplitView` but with:
- Wider sidebar (~260pt) using `DashboardSidebarItem` components
- Detail routes to `DashboardDetailView` (new) instead of the old tab-based layout
- Project creation/editing modes preserved via `DashboardMode` enum
- Sidebar header: "PROJECTS" + "+" button + search
- Remove `DashboardDetailTab` enum — no more tabs
- Remove references to `DetailPanel` and `WorkspacePanel` in the detail pane
- The detail for `.browsing` mode shows `DashboardDetailView(project:)` instead of the old tabbed view

Key changes to the sidebar section:
```swift
// Replace ProjectRowView usage with DashboardSidebarItem
ForEach(filteredProjects) { project in
    DashboardSidebarItem(
        project: project,
        isSelected: selectedProjectID == project.id,
        isActive: activityMonitor.isActive(projectID: project.id)
    )
    .onTapGesture {
        selectedProjectID = project.id
        mode = .browsing
    }
}
```

Key changes to the detail section:
```swift
// Replace the old tabbed detail with:
if let project = selectedProject {
    DashboardDetailView(project: project)
}
```

Add `@Environment(WorkspaceActivityMonitor.self) private var activityMonitor`.

Update sidebar width constraint to `DevtailTokens.Sizes.sidebarWidth`.

- [ ] **Step 2: Commit**

```bash
git add Devtail/Features/ContextSwitcher/Views/DashboardRootView.swift
git commit -m "feat(dashboard): rewrite with DashboardSidebarItem and DashboardDetailView"
```

---

## Phase 5: Cleanup

### Task 18: Remove deprecated files and update references

**Files:**
- Delete: `Devtail/Features/ContextSwitcher/Views/Components/DetailPanel.swift`
- Delete: `Devtail/Features/ContextSwitcher/Views/Components/WorkspacePaneRow.swift`
- Delete: `Devtail/Features/ContextSwitcher/Views/Components/TabHeader.swift`
- Modify: any files that import/reference deleted components

- [ ] **Step 1: Delete deprecated files**

```bash
cd /Volumes/Datos/Frelancer/DEVTAIL/Devtail
rm Devtail/Features/ContextSwitcher/Views/Components/DetailPanel.swift
rm Devtail/Features/ContextSwitcher/Views/Components/WorkspacePaneRow.swift
rm Devtail/Features/ContextSwitcher/Views/Components/TabHeader.swift
```

- [ ] **Step 2: Verify no remaining references**

```bash
rg "DetailPanel" Devtail/ --type swift
rg "WorkspacePaneRow" Devtail/ --type swift
rg "TabHeader\b" Devtail/ --type swift
rg "ContextSwitcherTab" Devtail/ --type swift
```

If any references found, update them (they should have been removed in Tasks 11 and 17).

- [ ] **Step 3: Remove unused tokens from DevtailTokens**

Check for tokens that are no longer referenced after the rewrite:
```bash
rg "detailPanelHeight" Devtail/ --type swift
rg "projectListHeight" Devtail/ --type swift
rg "pill\b" Devtail/DesignSystem/ --type swift
```

Remove any unreferenced tokens.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove DetailPanel, WorkspacePaneRow, TabHeader — replaced by new components"
```

---

### Task 19: Add tooltips to existing buttons

**Files:**
- Modify: `Devtail/Features/ContextSwitcher/Views/Components/WorkspaceLayoutPicker.swift` (already done in Task 15)
- Verify: all new components have `.help()` modifiers

- [ ] **Step 1: Audit all interactive elements for tooltips**

```bash
rg "\.help\(" Devtail/ --type swift
```

Verify coverage matches the tooltip table from the spec:
- Launch → "Launch workspace in Ghostty"
- + (add pane) → "Add a new terminal pane"
- + (add project) → "Create a new project"
- ✎ (edit pane) → "Edit pane settings"
- 🗑 (delete pane) → "Remove this pane"
- Configure in Dashboard... → "Open full dashboard to configure this workspace"
- Layout thumbnails → layout name

Add any missing `.help()` modifiers.

- [ ] **Step 2: Commit (if changes needed)**

```bash
git add -A
git commit -m "feat(ux): ensure all interactive elements have tooltips"
```

---

### Task 20: Final integration verification

- [ ] **Step 1: Verify all new files exist**

```bash
fd -t f -e swift . Devtail/DesignSystem/
fd -t f -e swift . Devtail/Features/ContextSwitcher/Services/
fd -t f -e swift . Devtail/Features/ContextSwitcher/Views/Components/ | sort
fd -t f . Devtail/Resources/Fonts/
fd -t f . Devtail/Assets.xcassets/Colors/
```

- [ ] **Step 2: Verify deleted files are gone**

```bash
test -f Devtail/Features/ContextSwitcher/Views/Components/DetailPanel.swift && echo "STILL EXISTS" || echo "OK deleted"
test -f Devtail/Features/ContextSwitcher/Views/Components/WorkspacePaneRow.swift && echo "STILL EXISTS" || echo "OK deleted"
test -f Devtail/Features/ContextSwitcher/Views/Components/TabHeader.swift && echo "STILL EXISTS" || echo "OK deleted"
```

- [ ] **Step 3: Verify no compilation references to deleted types**

```bash
rg "DetailPanel|WorkspacePaneRow|TabHeader|ContextSwitcherTab" Devtail/ --type swift -l
```

Expected: no files returned (or only test files that may need updating).

- [ ] **Step 4: Verify deployment target**

```bash
rg "MACOSX_DEPLOYMENT_TARGET" Devtail.xcodeproj/project.pbxproj
```

Expected: all lines show `26.0`.

- [ ] **Step 5: Verify font bundling**

```bash
ls -la Devtail/Resources/Fonts/
rg "ATSApplicationFontsPath" Devtail.xcodeproj/project.pbxproj
```

- [ ] **Step 6: Final commit if any fixes needed**

```bash
git add -A
git commit -m "chore: final integration verification cleanup"
```
