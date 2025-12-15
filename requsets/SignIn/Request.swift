//
//  Request.swift
//  SignIn
//
//  Created by BP-36-212-05 on 14/12/2025.
//

import Foundation
import FirebaseFirestore

import Foundation
import FirebaseFirestore

struct Request {
    var description: String
    var location: String
    var category: [String]  // List of categories like IT, Plumbing, etc.
    var priorityLevel: [String]  // List of priority levels like high, medium, low
    var status: [String]  // List of possible status values
    var assignedAt: Date?  // Timestamp when assigned
    var assignedTechnician: DocumentReference?  // Reference to the assigned technician
    var duplicateFlag: Bool  // Flag to mark duplicate requests
    var image: String?  // Reference to the image stored in storage
    var relatedTickets: [DocumentReference]  // References to related tickets
    var requestTitle: String  // Title for the request
    var submittedBy: DocumentReference  // Reference to the user who submitted the request

    // Initializer for creating a Request from Firestore Document
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        
        guard let title = data["title"] as? String,
              let description = data["description"] as? String,
              let location = data["location"] as? String,
              let category = data["category"] as? [String],
              let priorityLevel = data["priorityLevel"] as? [String],
              let status = data["status"] as? [String],
              let assignedAtTimestamp = data["assignedAt"] as? Timestamp,
              let assignedTechnician = data["assignedTechnician"] as? DocumentReference,
              let duplicateFlag = data["duplicateFlag"] as? Bool,
              let image = data["image"] as? String,
              let relatedTickets = data["relatedTickets"] as? [DocumentReference],
              let requestTitle = data["requestTitle"] as? String,
              let submittedBy = data["submittedBy"] as? DocumentReference else { return nil }
        
        
        self.description = description
        self.location = location
        self.category = category
        self.priorityLevel = priorityLevel
        self.status = status
        self.assignedAt = assignedAtTimestamp.dateValue()
        self.assignedTechnician = assignedTechnician
        self.duplicateFlag = duplicateFlag
        self.image = image
        self.relatedTickets = relatedTickets
        self.requestTitle = requestTitle
        self.submittedBy = submittedBy
    }
}



// Data Transfer Object (DTO) for creating a new request
struct RequestCreateDTO {
    var title: String
    var description: String
    var location: String
    var categoryIndex: Int
    var priorityIndex: Int
    var submittedBy: DocumentReference  // Reference to the user who submitted the request
    
    // Convert to Firestore-compatible dictionary
    func toDictionary() -> [String: Any] {
        return [
            "title": title,
            "description": description,
            "location": location,
            "categoryIndex": categoryIndex,
            "priorityIndex": priorityIndex,
            "submittedBy": submittedBy
        ]
    }
}


class RequestManager {
    static let shared = RequestManager()
    
    private init() {}
    
    // Firestore reference
    private let db = Firestore.firestore()
    
    // Method to add a new request
    func addRequest(_ request: RequestCreateDTO) async throws -> String {
        // Adding the request document to Firestore
        let docRef = try await db.collection("requests").addDocument(data: request.toDictionary())
        
        // Return the document ID of the newly created request
        return docRef.documentID
    }
    
    // Method to fetch all requests
    func fetchRequests(completion: @escaping ([Request]?, Error?) -> Void) {
        db.collection("requests").getDocuments { snapshot, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            var requests: [Request] = []
            for document in snapshot?.documents ?? [] {
                if let request = Request(document: document) {
                    requests.append(request)
                }
            }
            
            completion(requests, nil)
        }
    }
}

