//
//  RepairRequest.swift
//  
//
//  Created by BP-36-201-16 on 05/12/2025.
//

import Foundation

enum RequestStatus: String, Codable {
    case notAssigned = "Not Assigned"
    case assigned = "Assigned"
    case inProgress = "In Progress"
    case done = "Done"
    case canceled = "Canceled"
}

enum RequestPriority: String, Codable {
    case urgent = "Urgent"
    case moderate = "Moderate"
    case notice = "Notice"
}

struct RepairRequest: Identifiable, Codable {
    let id: String
    let submitterID: String
    var technicianID: String?
    var category: String
    var problemDescription: String
    var location: String // e.g., "Class 20, Building 19, Bathroom"
    var imageURL: String? // URL to the image showcasing the problem
    var priority: RequestPriority
    var status: RequestStatus
    let dateSubmitted: Date
    var dateResolved: Date?
    var isDuplicate: Bool = false
    var masterTicketID: String?
    var chatMessages: [ChatMessage] = []

    // Placeholder for a simple initializer
    init(id: String, submitterID: String, category: String, problemDescription: String, location: String, priority: RequestPriority, status: RequestStatus = .notAssigned, imageURL: String? = nil) {
        self.id = id
        self.submitterID = submitterID
        self.category = category
        self.problemDescription = problemDescription
        self.location = location
        self.priority = priority
        self.status = status
        self.dateSubmitted = Date()
        self.imageURL = imageURL
    }
}

struct ChatMessage: Identifiable, Codable {
    let id: String = UUID().uuidString
    let senderID: String
    let content: String
    let timestamp: Date
}
