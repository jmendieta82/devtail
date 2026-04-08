//
//  QuickLinkRepository.swift
//  Devtail
//
//  CRUD for QuickLink. Validates label + URL, normalizes URL with
//  https:// auto-prefix, calls try context.save() on every mutation
//  because the manual ModelContainer has autosave OFF.
//

import Foundation
import SwiftData

@MainActor
struct QuickLinkRepository: QuickLinkRepositoryProtocol {
    let context: ModelContext

    func create(label: String, url: String, project: Project) throws -> QuickLink {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else {
            throw QuickLinkError.invalidLabel
        }
        guard let normalizedURL = normalizeURL(url) else {
            throw QuickLinkError.invalidURL
        }
        let nextOrder = (project.quickLinks.map { $0.order }.max() ?? -1) + 1
        let link = QuickLink(
            label: trimmedLabel,
            url: normalizedURL,
            order: nextOrder,
            project: project
        )
        context.insert(link)
        try context.save()
        return link
    }

    func findByProject(_ project: Project) throws -> [QuickLink] {
        project.quickLinks.sorted { $0.order < $1.order }
    }

    func update(_ quickLink: QuickLink) throws {
        let trimmedLabel = quickLink.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else {
            throw QuickLinkError.invalidLabel
        }
        guard let normalizedURL = normalizeURL(quickLink.url) else {
            throw QuickLinkError.invalidURL
        }
        quickLink.label = trimmedLabel
        quickLink.url = normalizedURL
        quickLink.updatedAt = .now
        try context.save()
    }

    func delete(_ quickLink: QuickLink) throws {
        context.delete(quickLink)
        try context.save()
    }
}

/// Normalize a raw URL string. Auto-prefixes `https://` when no scheme
/// is present. Returns nil if the result is not parseable as a URL.
func normalizeURL(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let lower = trimmed.lowercased()
    if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
        return URL(string: trimmed) != nil ? trimmed : nil
    }
    let prefixed = "https://" + trimmed
    return URL(string: prefixed) != nil ? prefixed : nil
}
