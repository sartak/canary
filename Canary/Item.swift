//
//  Item.swift
//  Canary
//
//  Created by Shawn Moore on 7/29/25.
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
