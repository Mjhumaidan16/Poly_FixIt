//
//  Request.swift
//  SignIn
//
//  Created by BP-36-212-05 on 14/12/2025.
//

import Foundation
import FirebaseFirestore

// MARK: - Request Model (Read)
struct Request {
    let id: String
    let title: String
    let description: String
    let location: [String]
    let category: [String]
    let priority: [String]
    let submittedBy: DocumentReference?
    let assignedTechnician: DocumentReference?
    let relatedTickets: [DocumentReference]?
    let status: String
    let acceptanceTime: Timestamp?
    let completionTime: Timestamp?
    let assignedAt: Timestamp?
    let duplicateFlag: Bool
    let imageUrl: String?

    // Modify init for category and priority to handle array data properly
    init?(document: DocumentSnapshot) {
        let data = document.data() ?? [:]  // Ensure data is safely unwrapped

        // Extract fields from Firestore document
        guard
            let title = data["title"] as? String,
            let description = data["description"] as? String,
            let category = data["category"] as? [String],
            let priority = data["priority"] as? [String],
            let status = data["status"] as? String,
            let acceptanceTime = data["acceptanceTime"] as? Timestamp,
            let duplicateFlag = data["duplicateFlag"] as? Bool
        else {
            return nil  // If any of the required fields are missing, return nil
        }

        // Extract optional fields
        let submittedBy = data["submittedBy"] as? DocumentReference
        let assignedTechnician = data["assignedTechnician"] as? DocumentReference
        let relatedTickets = data["relatedTickets"] as? [DocumentReference] ?? []
        let completionTime = data["completionTime"] as? Timestamp
        let assignedAt = data["assignedAt"] as? Timestamp
        let imageUrl = data["imageUrl"] as? String

        // Extract location dictionary: [Campus, Building, Room]
        if let locationData = data["location"] as? [String: [String]],
           let campus = locationData["campus"]?.first,
           let building = locationData["building"]?.first,
           let room = locationData["room"]?.first {
            self.location = [campus, building, room]
        } else {
            self.location = []  // Fallback if location is missing or malformed
        }

        self.id = document.documentID
        self.title = title
        self.description = description
        self.category = category
        self.priority = priority
        self.submittedBy = submittedBy
        self.assignedTechnician = assignedTechnician
        self.relatedTickets = relatedTickets
        self.status = status
        self.acceptanceTime = acceptanceTime
        self.completionTime = completionTime
        self.assignedAt = assignedAt
        self.duplicateFlag = duplicateFlag
        self.imageUrl = imageUrl
    }

}



// MARK: - DTO (Write)
struct RequestCreateDTO{

    let title: String
    let description: String
    let location: [String: Any]
    let category: String
    let priority: String
    let submittedBy: DocumentReference? = nil
    let imageUrl: String
    let assignedTechnician: DocumentReference? = nil
    let relatedTickets: [DocumentReference] = []
    let status: String
    let acceptanceTime: Timestamp? = nil
    let completionTime: Timestamp? = nil
    let assignedAt: Timestamp?
    let duplicateFlag: Bool = false

    func toDictionary() -> [String: Any] {
        [
            "title": title,
                 "description": description,
                 "location": location,  // Save the location as a 3-element array
                 "category": category,
                 "priority": priority,
                 "submittedBy": submittedBy as Any,
                 "imageUrl": imageUrl,
                 "assignedTechnician": assignedTechnician as Any,  // Optional can be nil
                 "relatedTickets": relatedTickets,
                 "status": "Pending",
                 "acceptanceTime": acceptanceTime as Any,
                 "completionTime": completionTime  as Any,
                 "assignedAt": assignedAt  as Any,
                 "duplicateFlag": duplicateFlag,
                 "createdAt": Timestamp()
        ]
    }
}

//MARK: - DTO (edit)
struct RequestUpdateDTO{

    let title: String?
    let description: String?
    let location: [String: Any]?
    let categoryIndex: Int?
    let priorityIndex: Int?
    let imageUrl: String?
    let submittedBy: DocumentReference?
    let assignedTechnician: DocumentReference?
    let relatedTickets: [DocumentReference]?
    let status: String?
    let acceptanceTime: Timestamp?
    let completionTime: Timestamp?
    let assignedAt: Timestamp?
    let duplicateFlag: Bool?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]

        if let title { dict["title"] = title }
        if let description { dict["description"] = description }
        if let location { dict["location"] = location }
        if let categoryIndex { dict["categoryIndex"] = categoryIndex }
        if let priorityIndex { dict["priorityIndex"] = priorityIndex }
        if let imageUrl { dict["image"] = imageUrl }
        if let assignedTechnician { dict["assignedTechnician"] = assignedTechnician }
        if let relatedTickets { dict["relatedTickets"] = relatedTickets }
        if let status { dict["status"] = status }
        if let acceptanceTime { dict["acceptanceTime"] = acceptanceTime }
        if let completionTime { dict["completionTime"] = completionTime }
        if let assignedAt { dict["assignedAt"] = assignedAt }
        if let duplicateFlag { dict["duplicateFlag"] = duplicateFlag }

        dict["updatedAt"] = Timestamp()
        return dict
    }
}




final class RequestManager{
    
    static let shared = RequestManager()
    private init() {}
    
    private let db = Firestore.firestore()
    
    // MARK: - Add Request
    func addRequest(_ request: RequestCreateDTO) async throws -> String {
        let docRef = try await db
            .collection("requests")
            .addDocument(data: request.toDictionary())
        
        return docRef.documentID
    }
    
    // MARK: - Update Request
    func updateRequest(requestId: String, updateDTO: RequestUpdateDTO) async throws {
        let docRef = db.collection("requests").document(requestId)
        let updateData = updateDTO.toDictionary()
        try await docRef.updateData(updateData)
    }
    
    // MARK: - Fetch Request by ID
    // MARK: - Fetch Request by ID (Improved with Error Logging)
    func fetchRequest(requestId: String, completion: @escaping (Request?) -> Void) {
        print("Fetching request for requestId: \(requestId)")  // Debugging line
        
        db.collection("requests")
            .document(requestId)  // Fetch the document using the requestId
            .getDocument { snapshot, error in
                if let error = error {
                    print("Error fetching request: \(error.localizedDescription)")  // Log the error
                    completion(nil)
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else {
                    print("No request found for this ID.")
                    completion(nil)
                    return
                }
                
                // Debugging: Print the fetched document snapshot
                print("Fetched document snapshot: \(snapshot.data() ?? [:])")
                
                // Attempt to initialize the Request model with the fetched data
                if let request = Request(document: snapshot) {
                    print("Request successfully fetched and mapped.")
                    completion(request)
                } else {
                    print("Failed to map document data to Request model.")
                    completion(nil)
                }
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
