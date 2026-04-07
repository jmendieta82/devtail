//
//  CostSnapshot.swift
//  Devtail
//
//  A point-in-time cost reading from a cloud provider.
//

import Foundation
import SwiftData

@Model
final class CostSnapshot {
    @Attribute(.unique) var id: UUID
    var date: Date
    var totalCost: Double
    var currency: String

    /// JSON-encoded breakdown of cost per service (e.g. {"EC2": 12.5, "S3": 3.2}).
    /// Stored as a string so SwiftData can persist it without a custom transformer.
    var serviceCostsJSON: String

    var cloudAccount: CloudAccount?

    init(
        id: UUID = UUID(),
        date: Date,
        totalCost: Double,
        currency: String = "USD",
        serviceCostsJSON: String = "{}"
    ) {
        self.id = id
        self.date = date
        self.totalCost = totalCost
        self.currency = currency
        self.serviceCostsJSON = serviceCostsJSON
    }
}
