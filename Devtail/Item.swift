//
//  Item.swift
//  Devtail
//
//  Created by Javier Mendieta Ortega on 6/04/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
