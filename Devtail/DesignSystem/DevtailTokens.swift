//
//  DevtailTokens.swift
//  Devtail
//
//  Central design tokens for Devtail. Every color, font, spacing, size,
//  radius, and border width used by the app MUST come from this file.
//  Do NOT hardcode visual constants in views.
//
//  Colors use system semantic values and Asset Catalog references for
//  automatic light/dark mode support. Typography uses SF Pro for UI
//  and Ubuntu Mono (bundled) for monospace/code content.
//

import SwiftUI

enum DevtailTokens {

    // MARK: - Colors

    enum Colors {
        // === Backgrounds (system semantic — auto light/dark) ===
        static let appBackground        = Color(nsColor: .windowBackgroundColor)
        static let popoverBackground    = Color(nsColor: .controlBackgroundColor)
        static let cardBackground       = Color(nsColor: .controlBackgroundColor)
        static let inputBackground      = Color(nsColor: .textBackgroundColor)
        static let sidebar              = Color(nsColor: .windowBackgroundColor)
        static let hoverState           = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)

        // Backwards-compatible aliases (used by existing views, will be removed after full migration)
        static let titleBar             = Color(nsColor: .controlBackgroundColor)
        static let searchField          = Color(nsColor: .textBackgroundColor)
        static let pill                 = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
        static let activeRow            = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)

        // === Text (system semantic) ===
        static let textPrimary          = Color.primary
        static let textSecondary        = Color.secondary
        static let textTertiary         = Color(nsColor: .tertiaryLabelColor)
        static let textMuted            = Color(nsColor: .quaternaryLabelColor)
        static let textPlaceholder      = Color(nsColor: .placeholderTextColor)
        static let textDisabled         = Color(nsColor: .disabledControlTextColor)

        // === Borders (system semantic) ===
        static let borderPrimary        = Color(nsColor: .gridColor)
        static let borderSubtle         = Color(nsColor: .separatorColor)
        static let borderCard           = Color(nsColor: .separatorColor)

        // === Project Colors (Asset Catalog — auto light/dark) ===
        static let projectGreen         = Color("ProjectGreen")
        static let projectBlue          = Color("ProjectBlue")
        static let projectOrange        = Color("ProjectOrange")
        static let projectPurple        = Color("ProjectPurple")
        static let projectPink          = Color("ProjectPink")
        static let projectAmber         = Color("ProjectAmber")
        static let projectGray          = Color("ProjectGray")

        // === Semantic / Accent (Asset Catalog) ===
        static let accentPrimary        = Color(red: 0.475, green: 0.322, blue: 0.827)
        static let accentOrange         = Color("AccentOrange")

        // Retained accents (keep hardcoded — no light/dark variant needed yet)
        static let accentGreenLight     = Color(red: 0.365, green: 0.792, blue: 0.647) // #5DCAA5
        static let accentBlue           = Color(red: 0.522, green: 0.718, blue: 0.922) // #85B7EB
        static let accentPurpleLight    = Color(red: 0.686, green: 0.663, blue: 0.925) // #AFA9EC
        static let accentCoralLight     = Color(red: 0.941, green: 0.600, blue: 0.482) // #F0997B
        static let trendPositive        = Color(red: 0.388, green: 0.600, blue: 0.133) // #639922

        // === Secret Type Badges (unused until Phase 2) ===
        static let badgeDB              = Color("ProjectGreen")
        static let badgeAPI             = Color("ProjectBlue")
        static let badgeSSH             = Color("ProjectPurple")
        static let badgeURL             = Color("ProjectOrange")

        // === Traffic Light (currently unused) ===
        static let trafficRed           = Color(red: 1.000, green: 0.373, blue: 0.341) // #ff5f57
        static let trafficYellow        = Color(red: 0.996, green: 0.737, blue: 0.180) // #febc2e
        static let trafficGreen         = Color(red: 0.157, green: 0.784, blue: 0.251) // #28c840

        // === Menu Bar Icon ===
        static let menuBarIconBg        = Color("AccentGreen")
        static let menuBarIconText      = Color.white

        // === Activity ===
        static let activityGreen        = Color.green
    }

    // MARK: - Typography

    enum Typography {
        /// Single source of truth for the app's UI text scale, kept in sync
        /// with `AppSettings.uiFontSize` (MainActor-only mutation). Every
        /// font token below is computed relative to this value, preserving
        /// its historical delta from the legacy base of 12pt. Terminal
        /// rendering does NOT use these tokens — see `TerminalAppearance`.
        static var baseSize: CGFloat = 12

        /// Named font-size roles, used by `pointSize(for:)` so the delta
        /// math can be pinned by tests without reflecting into `Font`.
        enum Role {
            case projectTitle, titleLarge, titleMedium, headline
            case body, bodySemibold, bodyDefault, bodySmall, caption, captionSmall, micro
            case mono, monoSmall, monoBold, monoDefault
            case statValue, statValueSmall, statLabel, statSub
        }

        /// Point size for a role, relative to `baseSize`, preserving each
        /// role's original delta from the legacy fixed base of 12.
        static func pointSize(for role: Role) -> CGFloat {
            switch role {
            case .projectTitle:   return baseSize + 6
            case .titleLarge:     return baseSize + 6
            case .titleMedium:    return baseSize + 2
            case .headline:       return baseSize + 1
            case .body:           return baseSize + 2
            case .bodySemibold:   return baseSize + 2
            case .bodyDefault:    return baseSize + 1
            case .bodySmall:      return baseSize
            case .caption:        return baseSize
            case .captionSmall:   return baseSize - 2
            case .micro:          return baseSize - 3
            case .mono:           return baseSize + 1
            case .monoSmall:      return baseSize - 1
            case .monoBold:       return baseSize + 1
            case .monoDefault:    return baseSize
            case .statValue:      return baseSize + 8
            case .statValueSmall: return baseSize + 2
            case .statLabel:      return baseSize - 1
            case .statSub:        return baseSize - 1
            }
        }

        // === Titles ===
        static var projectTitle: Font { Font.system(size: pointSize(for: .projectTitle), weight: .semibold) }
        static var titleLarge: Font   { Font.system(size: pointSize(for: .titleLarge), weight: .medium) }
        static var titleMedium: Font  { Font.system(size: pointSize(for: .titleMedium), weight: .medium) }
        static var headline: Font     { Font.system(size: pointSize(for: .headline), weight: .medium) }

        // === Body ===
        static var body: Font           { Font.system(size: pointSize(for: .body)) }
        static var bodySemibold: Font   { Font.system(size: pointSize(for: .bodySemibold), weight: .semibold) }
        static var bodyDefault: Font    { Font.system(size: pointSize(for: .bodyDefault)) }
        static var bodySmall: Font      { Font.system(size: pointSize(for: .bodySmall)) }
        static var caption: Font        { Font.system(size: pointSize(for: .caption)) }
        static var captionSmall: Font   { Font.system(size: pointSize(for: .captionSmall)) }
        static var micro: Font          { Font.system(size: pointSize(for: .micro)) }

        // === Monospace (Ubuntu Mono — bundled) ===
        static var mono: Font      { Font.custom("UbuntuMono-Regular", size: pointSize(for: .mono)) }
        static var monoSmall: Font { Font.custom("UbuntuMono-Regular", size: pointSize(for: .monoSmall)) }
        static var monoBold: Font  { Font.custom("UbuntuMono-Bold", size: pointSize(for: .monoBold)) }

        // Backwards-compatible aliases
        static var monoDefault: Font { Font.custom("UbuntuMono-Regular", size: pointSize(for: .monoDefault)) }

        // === Stat Cards (unused until Phase 3) ===
        static var statValue: Font      { Font.system(size: pointSize(for: .statValue), weight: .medium) }
        static var statValueSmall: Font { Font.system(size: pointSize(for: .statValueSmall), weight: .medium) }
        static var statLabel: Font      { Font.system(size: pointSize(for: .statLabel)) }
        static var statSub: Font        { Font.system(size: pointSize(for: .statSub)) }
    }

    // MARK: - Spacing (in points)

    enum Spacing {
        // === Global padding ===
        static let popoverPadding: CGFloat       = 16
        static let dashboardPadding: CGFloat     = 24
        static let cardPadding: CGFloat          = 14
        static let cardPaddingLarge: CGFloat     = 14
        static let sidebarItemPadding: CGFloat   = 14
        static let sidebarItemVertical: CGFloat  = 12

        // === Gaps ===
        static let gapTiny: CGFloat              = 2
        static let gapSmall: CGFloat             = 4
        static let gapMedium: CGFloat            = 8
        static let gapDefault: CGFloat           = 10
        static let gapLarge: CGFloat             = 14
        static let gapSection: CGFloat           = 24
        static let gapSectionTitle: CGFloat      = 6
        static let gapXLarge: CGFloat            = 20

        // === Margins / Section ===
        static let sectionBottom: CGFloat        = 20
        static let headerBottom: CGFloat         = 12
        static let sectionTitleBottom: CGFloat   = 6
        static let searchVertical: CGFloat       = 8
    }

    // MARK: - Sizes

    enum Sizes {
        // === Popover ===
        static let popoverWidth: CGFloat         = 400
        static let popoverMaxHeight: CGFloat     = 480
        static let popoverHeight: CGFloat        = 480  // alias for popoverMaxHeight

        static let titleBarHeight: CGFloat       = 38

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
        static let sidebarDot: CGFloat           = 7
        static let activityDotSize: CGFloat      = 8

        // === Legacy (kept for views not yet migrated) ===
        static let menuBarHeight: CGFloat        = 28
        static let projectListHeight: CGFloat    = 180
        static let detailPanelHeight: CGFloat    = 220
        static let trafficDot: CGFloat           = 12
        static let searchIconSize: CGFloat       = 12
        static let actionIconSize: CGFloat       = 10
        static let colorPickerDot: CGFloat       = 24
        static let tabIconSize: CGFloat          = 14
    }

    // MARK: - Corner Radius

    enum Radius {
        static let badge: CGFloat                = 3
        static let pill: CGFloat                 = 4
        static let chip: CGFloat                 = 6
        static let searchField: CGFloat          = 6
        static let sidebarItem: CGFloat          = 6
        static let card: CGFloat                 = 8
        static let popover: CGFloat              = 10
        static let window: CGFloat               = 12

        // Backwards-compatible aliases
        static let secretBadge: CGFloat          = 4
        static let actionButton: CGFloat         = 4
        static let tab: CGFloat                  = 5
        static let linkChip: CGFloat             = 5
        static let projectRow: CGFloat           = 8
    }

    // MARK: - Border Width

    enum BorderWidth {
        static let `default`: CGFloat            = 0.5
        static let accentStrip: CGFloat          = 3
    }

    // MARK: - Active States & Opacity

    enum ActiveState {
        static let activeBgOpacity: Double       = 0.094
        static let activeBorderOpacity: Double   = 0.251
        static let badgeBgOpacity: Double        = 0.125
        static let hoverBgOpacity: Double        = 1.0
    }
}

// MARK: - Color helpers

extension Color {
    static func secretBadgeBg(_ color: Color) -> Color {
        color.opacity(DevtailTokens.ActiveState.badgeBgOpacity)
    }

    static var activeProjectBg: Color {
        DevtailTokens.Colors.accentPrimary.opacity(DevtailTokens.ActiveState.activeBgOpacity)
    }

    static var activeProjectBorder: Color {
        DevtailTokens.Colors.accentPrimary.opacity(DevtailTokens.ActiveState.activeBorderOpacity)
    }
}
