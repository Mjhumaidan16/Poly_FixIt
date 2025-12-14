//
//  Request.swift
//  SignIn
//
//  Created by BP-36-212-05 on 14/12/2025.
//

import Foundation
import FirebaseFirestore

struct Request {
    var title: String
    var description: String
    var location: String
    var categoryIndex: Int
    var priorityIndex: Int
    var submittedBy: String  // User's ID or email or something that identifies the user
    
    // Initializer for creating a Request from Firestore Document
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        
        guard let title = data["title"] as? String,
              let description = data["description"] as? String,
              let location = data["location"] as? String,
              let categoryIndex = data["categoryIndex"] as? Int,
              let priorityIndex = data["priorityIndex"] as? Int,
              let submittedBy = data["submittedBy"] as? String else { return nil }
        
        self.title = title
        self.description = description
        self.location = location
        self.categoryIndex = categoryIndex
        self.priorityIndex = priorityIndex
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

