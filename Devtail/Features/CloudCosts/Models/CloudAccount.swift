//
//  CloudAccount.swift
//  Devtail
//
//  Represents a cloud provider account linked to a project.
//  Credentials live in macOS Keychain, never in SwiftData.
//

import Foundation
import SwiftData

enum CloudProvider: String, Codable, CaseIterable {
    case aws
    case gcp
    case azure
}

@Model
final class CloudAccount {
    @Attribute(.unique) var id: UUID
    var providerRaw: String
    var profileName: String
    var region: String
    var createdAt: Date

    var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \CostSnapshot.cloudAccount)
    var costSnapshots: [CostSnapshot] = []

    var provider: CloudProvider {
        get { CloudProvider(rawValue: providerRaw) ?? .aws }
        set { providerRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        provider: CloudProvider,
        profileName: String,
        region: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.providerRaw = provider.rawValue
        self.profileName = profileName
        self.region = region
        self.createdAt = createdAt
    }
}
