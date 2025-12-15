//
//  Request.swift
//  SignIn
//
//  Created by BP-36-212-05 on 14/12/2025.
//


import Foundation
import FirebaseFirestore

// MARK: - Request Model (Read)
struct Request2 {

    let id: String
    let title: String
    let description: String
    let location: [String: Any] // Assuming the location is a dictionary/map
    let category: [String]
    let priorityLevel: [String]
    let assignedTechnician: DocumentReference
    let relatedTickets: [DocumentReference]
    let status: [String]
    let acceptanceTime: Timestamp
    let assignedAt: Timestamp
    let duplicateFlag: Bool
    let imageReference: String?

    let building: [String]
    let campus: [String]
    let room: [String]

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()

        guard
            let title = data["requestTitle"] as? String,
            let description = data["problemDescription"] as? String,
            let category = data["category"] as? [String],
            let priorityLevel = data["priorityLevel"] as? [String],
            let assignedTechnician = data["assignedTechnician"] as? DocumentReference,
            let relatedTickets = data["relatedTickets"] as? [DocumentReference],
            let status = data["status"] as? [String],
            let acceptanceTime = data["AcceptanceTime"] as? Timestamp,
            let assignedAt = data["assignedAt"] as? Timestamp,
            let duplicateFlag = data["duplicateFlag"] as? Bool
        else {
            return nil
        }
        
        let imageReference = data["image"] as? String
        
        // Extract building, campus, and room from the location map
        let location = data["location"] as? [String: Any] ?? [:]
        let building = location["building"] as? [String] ?? []
        let campus = location["campus"] as? [String] ?? []
        let room = location["room"] as? [String] ?? []

           self.id = document.documentID
           self.title = title
           self.description = description
           self.category = category
           self.priorityLevel = priorityLevel
           self.assignedTechnician = assignedTechnician
           self.relatedTickets = relatedTickets
           self.status = status
           self.acceptanceTime = acceptanceTime
           self.assignedAt = assignedAt
           self.duplicateFlag = duplicateFlag
           self.imageReference = imageReference
           self.building = building
           self.campus = campus
           self.room = room
           self.location = location
    }
}


// MARK: - DTO (Write)
struct RequestCreateDTO2 {

    let title: String
    let description: String
    let location: [String: Any]
    let categoryIndex: Int
    let priorityIndex: Int
    let submittedBy: DocumentReference

    func toDictionary() -> [String: Any] {
        [
            "title": title,
            "description": description,
            "location": location,
            "categoryIndex": categoryIndex,
            "priorityIndex": priorityIndex,
            "submittedBy": submittedBy,
            "createdAt": Timestamp()
        ]
    }
}


final class RequestManager2 {
    
    static let shared = RequestManager2()
    private init() {}

    private let db = Firestore.firestore()

    // MARK: - Add Request
    func addRequest(_ request: RequestCreateDTO2) async throws -> String {
        let docRef = try await db
            .collection("requests")
            .addDocument(data: request.toDictionary())

        return docRef.documentID
    }

    // MARK: - Fetch Requests
    func fetchRequests(completion: @escaping (Result<[Request2], Error>) -> Void) {
        db.collection("requests").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            let requests = snapshot?.documents.compactMap {
                Request2(document: $0)
            } ?? []

            completion(.success(requests))
        }
    }

    // MARK: - Fetch Shared Data (Document UID "001")
    func fetchSharedData(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        db.collection("requests").document("001").getDocument { documentSnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = documentSnapshot else {
                completion(.failure(NSError(domain: "FirestoreError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Document not found."])))
                return
            }
            
            // Check if the document exists
            if document.exists {
                // Fetch the data from the document
                let data = document.data() ?? [:]
                
                // Print the data or pass it to the completion handler
                print("Shared data:", data)  // You can print it or use it as needed
                
                completion(.success(data))  // Return the data
            } else {
                completion(.failure(NSError(domain: "FirestoreError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Document not found."])))
            }
        }
    }
}

