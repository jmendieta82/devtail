//
//  QuickLinkCategory.swift
//  Devtail
//
//  Heuristic classification of a quick link based on its URL host.
//  Used by QuickLinkChip to pick an SF Symbol AND by QuickLinksPanel to
//  group chips under section headers. Single source of truth so a link's
//  icon and group always agree.
//
//  The categorization is best-effort: hosts we don't recognize fall into
//  `.other`. No data model changes — category is derived, not persisted.
//

import Foundation

enum QuickLinkCategory: String, CaseIterable, Sendable {
    case repositories
    case docs
    case design
    case projectManagement
    case cloud
    case communication
    case localhost
    case other

    /// Display order for section headers in the panel. Most-used categories
    /// first; `.other` always last so mystery links don't push typed ones
    /// down the screen.
    static let displayOrder: [QuickLinkCategory] = [
        .repositories,
        .docs,
        .design,
        .projectManagement,
        .cloud,
        .communication,
        .localhost,
        .other
    ]

    /// Human-readable header shown above the chip grid for this group.
    var header: String {
        switch self {
        case .repositories:      return "REPOSITORIES"
        case .docs:              return "DOCS"
        case .design:            return "DESIGN"
        case .projectManagement: return "PROJECT MANAGEMENT"
        case .cloud:             return "CLOUD"
        case .communication:     return "COMMUNICATION"
        case .localhost:         return "LOCAL"
        case .other:             return "OTHER"
        }
    }

    /// SF Symbol name shown inside a chip that belongs to this category.
    var iconName: String {
        switch self {
        case .repositories:      return "chevron.left.forwardslash.chevron.right"
        case .docs:              return "doc.text"
        case .design:            return "paintpalette"
        case .projectManagement: return "checklist"
        case .cloud:             return "cloud"
        case .communication:     return "bubble.left.and.bubble.right"
        case .localhost:         return "terminal"
        case .other:             return "link"
        }
    }

    /// Maps a URL string to a category using host-based heuristics.
    /// Unrecognized / unparseable URLs land in `.other`.
    static func classify(urlString: String) -> QuickLinkCategory {
        guard let host = URL(string: urlString)?.host?.lowercased() else {
            // No host → if it literally starts with localhost:/127./192.168. it's still local.
            let trimmed = urlString.trimmingCharacters(in: .whitespaces).lowercased()
            if trimmed.contains("localhost") || trimmed.contains("127.0.0.1") {
                return .localhost
            }
            return .other
        }

        // Git hosts.
        if host.contains("github.com")
            || host.contains("gitlab.")
            || host.contains("bitbucket.")
            || host.contains("codeberg.")
            || host.contains("sourcehut.")
            || host.contains("gitea.") {
            return .repositories
        }
        // Docs / knowledge bases.
        if host.contains("notion.so")
            || host.contains("notion.site")
            || host.contains("confluence.")
            || host.contains("readme.io")
            || host.contains("gitbook.")
            || host.contains("docs.") {
            return .docs
        }
        // Design tools.
        if host.contains("figma.com")
            || host.contains("sketch.com")
            || host.contains("zeplin.io")
            || host.contains("invisionapp.com") {
            return .design
        }
        // Issue trackers / PM.
        if host.contains("atlassian.net")
            || host.contains("jira.")
            || host.contains("linear.app")
            || host.contains("trello.com")
            || host.contains("asana.com") {
            return .projectManagement
        }
        // Cloud consoles.
        if host.contains("aws.amazon.com")
            || host.contains("console.cloud.google.com")
            || host.contains("portal.azure.com")
            || host.contains("vercel.com")
            || host.contains("netlify.")
            || host.contains("render.com")
            || host.contains("fly.io") {
            return .cloud
        }
        // Communication.
        if host.contains("slack.com") || host.contains("discord.com") {
            return .communication
        }
        // Local network / dev servers.
        if host == "localhost"
            || host.hasPrefix("127.")
            || host.hasPrefix("192.168.")
            || host.hasPrefix("10.") {
            return .localhost
        }
        return .other
    }
}
