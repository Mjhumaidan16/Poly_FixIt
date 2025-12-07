//
// InventoryItem.swift
// PolyFixit
//
// Created by Manus AI on 2025/12/07.
//

import Foundation

struct InventoryItem: Identifiable, Codable {
    let id: String
    var name: String
    var category: String
    var currentQuantity: Int
    var minimumThreshold: Int
}
