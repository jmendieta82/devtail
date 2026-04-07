//
//  DevtailTokens.swift
//  Devtail
//
//  Central design tokens for Devtail. Every color, font, spacing, size,
//  radius, and border width used by the app MUST come from this file.
//  Do NOT hardcode visual constants in views.
//
//  Notes:
//  - Some tokens reference modules that are out of scope for the current
//    change (Secrets, AWS, Dashboard). They live here as data but are
//    unused until their feature lands. Do NOT remove them.
//  - Project colors are consumed via the `ProjectColor` enum, which maps
//    each case to the corresponding Colors.project* token.
//

import SwiftUI

enum DevtailTokens {

    // MARK: - Colors

    enum Colors {
        // === Backgrounds ===
        static let appBackground        = Color(red: 0.118, green: 0.118, blue: 0.118) // #1e1e1e
        static let titleBar             = Color(red: 0.165, green: 0.165, blue: 0.165) // #2a2a2a
        static let sidebar              = Color(red: 0.145, green: 0.145, blue: 0.145) // #252525
        static let popoverBackground    = Color(red: 0.176, green: 0.176, blue: 0.176) // #2d2d2d
        static let searchField          = Color(red: 0.133, green: 0.133, blue: 0.133) // #222222
        static let cardBackground       = Color(red: 0.165, green: 0.165, blue: 0.165) // #2a2a2a
        static let pill                 = Color(red: 0.200, green: 0.200, blue: 0.200) // #333333
        static let hoverState           = Color(red: 0.208, green: 0.208, blue: 0.208) // #353535
        static let activeRow            = Color(red: 0.208, green: 0.208, blue: 0.208) // #353535
        static let inputBackground      = Color(red: 0.133, green: 0.133, blue: 0.133) // #222222

        // === Text ===
        static let textPrimary          = Color(red: 0.933, green: 0.933, blue: 0.933) // #eeeeee
        static let textSecondary        = Color(red: 0.831, green: 0.831, blue: 0.831) // #d4d4d4
        static let textTertiary         = Color(red: 0.533, green: 0.533, blue: 0.533) // #888888
        static let textMuted            = Color(red: 0.467, green: 0.467, blue: 0.467) // #777777
        static let textPlaceholder      = Color(red: 0.400, green: 0.400, blue: 0.400) // #666666
        static let textDisabled         = Color(red: 0.267, green: 0.267, blue: 0.267) // #444444

        // === Borders ===
        static let borderPrimary        = Color(red: 0.267, green: 0.267, blue: 0.267) // #444444
        static let borderSubtle         = Color(red: 0.227, green: 0.227, blue: 0.227) // #3a3a3a
        static let borderCard           = Color(red: 0.200, green: 0.200, blue: 0.200) // #333333

        // === Project Colors (dots in sidebar and list) ===
        static let projectGreen         = Color(red: 0.114, green: 0.620, blue: 0.459) // #1D9E75
        static let projectBlue          = Color(red: 0.216, green: 0.541, blue: 0.867) // #378ADD
        static let projectOrange        = Color(red: 0.847, green: 0.353, blue: 0.188) // #D85A30
        static let projectPurple        = Color(red: 0.498, green: 0.467, blue: 0.867) // #7F77DD
        static let projectPink          = Color(red: 0.831, green: 0.325, blue: 0.494) // #D4537E
        static let projectAmber         = Color(red: 0.729, green: 0.459, blue: 0.090) // #BA7517
        static let projectGray          = Color(red: 0.533, green: 0.529, blue: 0.502) // #888780

        // === Semantic / Accent ===
        static let accentGreen          = Color(red: 0.114, green: 0.620, blue: 0.459) // #1D9E75
        static let accentGreenLight     = Color(red: 0.365, green: 0.792, blue: 0.647) // #5DCAA5
        static let accentBlue           = Color(red: 0.522, green: 0.718, blue: 0.922) // #85B7EB
        static let accentOrange         = Color(red: 0.937, green: 0.624, blue: 0.153) // #EF9F27
        static let accentPurpleLight    = Color(red: 0.686, green: 0.663, blue: 0.925) // #AFA9EC
        static let accentCoralLight     = Color(red: 0.941, green: 0.600, blue: 0.482) // #F0997B
        static let trendPositive        = Color(red: 0.388, green: 0.600, blue: 0.133) // #639922

        // === Secret Type Badges (unused until Phase 2) ===
        static let badgeDB              = Color(red: 0.114, green: 0.620, blue: 0.459) // #1D9E75
        static let badgeAPI             = Color(red: 0.216, green: 0.541, blue: 0.867) // #378ADD
        static let badgeSSH             = Color(red: 0.498, green: 0.467, blue: 0.867) // #7F77DD
        static let badgeURL             = Color(red: 0.847, green: 0.353, blue: 0.188) // #D85A30

        // === Traffic Light (dashboard title bar, unused until Dashboard change) ===
        static let trafficRed           = Color(red: 1.000, green: 0.373, blue: 0.341) // #ff5f57
        static let trafficYellow        = Color(red: 0.996, green: 0.737, blue: 0.180) // #febc2e
        static let trafficGreen         = Color(red: 0.157, green: 0.784, blue: 0.251) // #28c840

        // === Menu Bar Icon ===
        static let menuBarIconBg        = Color(red: 0.114, green: 0.620, blue: 0.459) // #1D9E75
        static let menuBarIconText      = Color.white
    }

    // MARK: - Typography

    enum Typography {
        // === Dashboard ===
        static let titleLarge           = Font.system(size: 18, weight: .medium)
        static let titleMedium          = Font.system(size: 14, weight: .medium)
        static let headline             = Font.system(size: 13, weight: .medium)

        // === Body ===
        static let bodyDefault          = Font.system(size: 13)
        static let bodySmall            = Font.system(size: 12)
        static let caption              = Font.system(size: 11)
        static let captionSmall         = Font.system(size: 10)
        static let micro                = Font.system(size: 9)

        // === Monospace ===
        static let monoDefault          = Font.system(size: 12, design: .monospaced)
        static let monoSmall            = Font.system(size: 11, design: .monospaced)

        // === Stat Cards ===
        static let statValue            = Font.system(size: 20, weight: .medium)
        static let statValueSmall       = Font.system(size: 14, weight: .medium)
        static let statLabel            = Font.system(size: 11)
        static let statSub              = Font.system(size: 11)
    }

    // MARK: - Spacing (in points)

    enum Spacing {
        // === Global padding ===
        static let popoverPadding: CGFloat       = 14
        static let dashboardPadding: CGFloat     = 24
        static let cardPadding: CGFloat          = 12
        static let cardPaddingLarge: CGFloat     = 14
        static let sidebarItemPadding: CGFloat   = 14
        static let sidebarItemVertical: CGFloat  = 6

        // === Gaps ===
        static let gapTiny: CGFloat              = 2
        static let gapSmall: CGFloat             = 4
        static let gapMedium: CGFloat            = 8
        static let gapDefault: CGFloat           = 10
        static let gapLarge: CGFloat             = 12
        static let gapSection: CGFloat           = 16
        static let gapXLarge: CGFloat            = 20

        // === Margins / Section ===
        static let sectionBottom: CGFloat        = 20
        static let headerBottom: CGFloat         = 12
        static let sectionTitleBottom: CGFloat   = 6
        static let searchVertical: CGFloat       = 8
    }

    // MARK: - Sizes

    enum Sizes {
        // === Menu Bar ===
        static let menuBarHeight: CGFloat        = 28
        static let popoverWidth: CGFloat         = 320
        static let popoverHeight: CGFloat        = 480   // consume as maxHeight, not fixed

        // === Dashboard ===
        static let dashboardWidth: CGFloat       = 900
        static let dashboardHeight: CGFloat      = 600
        static let sidebarWidth: CGFloat         = 200
        static let titleBarHeight: CGFloat       = 38

        // === Elements ===
        static let projectDot: CGFloat           = 8
        static let projectDotLarge: CGFloat      = 10
        static let sidebarDot: CGFloat           = 7
        static let trafficDot: CGFloat           = 12
        static let searchIconSize: CGFloat       = 12
        static let actionIconSize: CGFloat       = 10
        static let tabIconSize: CGFloat          = 14
    }

    // MARK: - Corner Radius

    enum Radius {
        static let badge: CGFloat                = 3
        static let pill: CGFloat                 = 4
        static let secretBadge: CGFloat          = 4
        static let actionButton: CGFloat         = 4
        static let tab: CGFloat                  = 5
        static let linkChip: CGFloat             = 5
        static let searchField: CGFloat          = 6
        static let sidebarItem: CGFloat          = 6
        static let projectRow: CGFloat           = 8
        static let card: CGFloat                 = 8
        static let popover: CGFloat              = 10
        static let window: CGFloat               = 12
    }

    // MARK: - Border Width

    enum BorderWidth {
        static let `default`: CGFloat            = 0.5
    }

    // MARK: - Active States & Opacity

    enum ActiveState {
        static let activeBgOpacity: Double       = 0.094 // #1D9E7518
        static let activeBorderOpacity: Double   = 0.251 // #1D9E7540
        static let badgeBgOpacity: Double        = 0.125
        static let hoverBgOpacity: Double        = 1.0
    }
}

// MARK: - Color helpers

extension Color {
    /// Background color for a secret-type badge, with the canonical opacity.
    static func secretBadgeBg(_ color: Color) -> Color {
        color.opacity(DevtailTokens.ActiveState.badgeBgOpacity)
    }

    /// Background color for an active/selected project row.
    static var activeProjectBg: Color {
        DevtailTokens.Colors.accentGreen.opacity(DevtailTokens.ActiveState.activeBgOpacity)
    }

    /// Border color for an active/selected project row.
    static var activeProjectBorder: Color {
        DevtailTokens.Colors.accentGreen.opacity(DevtailTokens.ActiveState.activeBorderOpacity)
    }
}
