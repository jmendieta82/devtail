//
//  QuickLinkRepositoryProtocol.swift
//  Devtail
//
//  Contract the ProjectStore depends on for QuickLink persistence,
//  decoupling it from SwiftData.
//

import Foundation

@MainActor
protocol QuickLinkRepositoryProtocol {
    func create(label: String, url: String, project: Project) throws -> QuickLink
    func findByProject(_ project: Project) throws -> [QuickLink]
    func update(_ quickLink: QuickLink) throws
    func delete(_ quickLink: QuickLink) throws
}
