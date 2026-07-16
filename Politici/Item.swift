//
//  Item.swift
//  Politici
//
//  Created by Giulio Carpi Lapi on 16/07/2026.
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
