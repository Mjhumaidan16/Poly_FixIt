//
//  UserModel.swift
//  
//
//  Created by BP-36-201-16 on 05/12/2025.
//

import Foundation

struct InventoryItem: Identifiable, Codable {
    let id: String
    var name: String
    var category: String
    var currentQuantity: Int
    var minimumThreshold: Int
}
