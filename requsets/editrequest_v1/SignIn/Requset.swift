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
    var category: [String]
    let priorityLevel: [String]
    /// The user-chosen category (stored in Firestore as `selectedCategory`)
    let selectedCategory: String?
    /// The user-chosen priority (stored in Firestore as `selectedPriorityLevel`)
    let selectedPriorityLevel: String?
    let submittedBy: DocumentReference?
    let assignedTechnician: DocumentReference?
    let relatedTickets: [DocumentReference]?
    let status: String
    let acceptanceTime: Timestamp?
    let completionTime: Timestamp?
    let assignedAt: Timestamp?
    let duplicateFlag: Bool
    let imageUrl: String?
    let createdAt: Timestamp
    
    // Modify init for category and priority to handle array data properly
    init?(document: DocumentSnapshot) {
        let data = document.data() ?? [:]  // Ensure data is safely unwrapped
        
        // Debugging: print out the whole data dictionary to see what's coming from Firestore
        //print("Document data:", data)

        // Extract fields from Firestore document
        guard
            let title = data["title"] as? String,
            let description = data["description"] as? String,
            //let category = data["category"] as? [String],  // Category is now an array of strings
            let priorityLevel = data["priorityLevel"] as? [String],  // PriorityLevel is now an array of strings
            let status = data["status"] as? String,
            let createdAt = data["createdAt"] as? Timestamp
          
            
        else {
            print("Error: Missing required fields.")  // Debugging line for missing fields
            return nil  // If any of the required fields are missing, return nil
        }

        // Extract optional fields
        let submittedBy = data["submittedBy"] as? DocumentReference
        let category = (data["category"] as? [String]) ?? []
        let assignedTechnician = data["assignedTechnician"] as? DocumentReference
        let acceptanceTime = data["acceptanceTime"] as? Timestamp
        let duplicateFlag = data["duplicateFlag"] as? Bool ?? false
        let relatedTickets = data["relatedTickets"] as? [DocumentReference] ?? []
        let completionTime = data["completionTime"] as? Timestamp
        let assignedAt = data["assignedAt"] as? Timestamp
        // Some older writes used the key `image` instead of `imageUrl`.
        let imageUrl = (data["imageUrl"] as? String) ?? (data["image"] as? String)

        let selectedCategory = data["selectedCategory"] as? String
        let selectedPriorityLevel = data["selectedPriorityLevel"] as? String

        // Debugging: print the location data
        if let locationData = data["location"] as? [String: [String]] {
            print("Location data:", locationData)  // Print the entire location data
            
            // Ensure each key exists and the arrays are not empty
            if let campusArray = locationData["campus"],
               let buildingArray = locationData["building"],
               let roomArray = locationData["room"] {
                // Debugging: print the arrays to verify they contain data
                print("Campus array:", campusArray)
                print("Building array:", buildingArray)
                print("Room array:", roomArray)
                
                // Only use the first element from each array, and handle potential empty arrays
                let campus = campusArray.first ?? ""
                let building = buildingArray.first ?? ""
                let room = roomArray.first ?? ""
                
                // Debugging: print what you're using to populate the location
                print("Campus:", campus)
                print("Building:", building)
                print("Room:", room)
                
                self.location = [campus, building, room]
            } else {
                print("Error: Missing or malformed location arrays.")  // Debugging line for missing arrays
                self.location = []
            }
        } else {
            print("Error: Location data is missing or malformed.")  // Debugging line for missing location
            self.location = []
        }

        // Now map the other fields as before...
        self.id = document.documentID
        self.title = title
        self.description = description
        self.category = category  // Category is now directly mapped as an array
        self.priorityLevel = priorityLevel  // PriorityLevel is now directly mapped as an array
        self.submittedBy = submittedBy
        self.assignedTechnician = assignedTechnician
        self.relatedTickets = relatedTickets
        self.status = status
        self.acceptanceTime = acceptanceTime
        self.completionTime = completionTime
        self.assignedAt = assignedAt
        self.duplicateFlag = duplicateFlag
        self.imageUrl = imageUrl
        self.selectedCategory = selectedCategory
        self.selectedPriorityLevel = selectedPriorityLevel
        self.createdAt = createdAt
    }


}



// MARK: - DTO (Write)
struct RequestCreateDTO{

    let title: String?
    let description: String?
    let location: [String: Any]?
    var category: [String]
    let priorityLevel: [String]
    let selectedCategory: String?
    let selectedPriorityLevel: String?
    let imageUrl: String?
    let submittedBy: DocumentReference
    let assignedTechnician: DocumentReference?
    let relatedTickets: [DocumentReference]?
    let status: String?
    let acceptanceTime: Timestamp?
    let completionTime: Timestamp?
    let assignedAt: Timestamp?
    let duplicateFlag: Bool?
    let createdAt: Timestamp

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]

        if let title { dict["title"] = title }
        if let description { dict["description"] = description }
        if let location { dict["location"] = location }
        dict["category"] = category
        dict["priorityLevel"] = priorityLevel
        if let selectedCategory { dict["selectedCategory"] = selectedCategory }
        if let selectedPriorityLevel { dict["selectedPriorityLevel"] = selectedPriorityLevel }
        if let imageUrl { dict["imageUrl"] = imageUrl }
        dict["submittedBy"] = submittedBy
        dict["assignedTechnician"] = assignedTechnician ?? NSNull()
        if let relatedTickets { dict["relatedTickets"] = relatedTickets }
        if let status { dict["status"] = status }
        dict["acceptanceTime"] = acceptanceTime ?? NSNull()  // Optional fields
        dict["completionTime"] = completionTime ?? NSNull()
        dict["assignedAt"] = assignedAt ?? NSNull()
        if let duplicateFlag { dict["duplicateFlag"] = duplicateFlag }
       dict["createdAt"] = createdAt
        return dict
    }
}

//MARK: - DTO (edit)
struct RequestUpdateDTO{

    let title: String?
    let description: String?
    let location: [String: Any]?
    var category: [String]
    let priorityLevel: [String]
    let selectedCategory: String?
    let selectedPriorityLevel: String?
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
        dict["category"] = category
        dict["priorityLevel"] = priorityLevel
        if let selectedCategory { dict["selectedCategory"] = selectedCategory }
        if let selectedPriorityLevel { dict["selectedPriorityLevel"] = selectedPriorityLevel }
        if let imageUrl { dict["imageUrl"] = imageUrl }
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

        // MARK: - Fetch Request
        func fetchRequest(requestId: String, completion: @escaping (Request?) -> Void) {
            print("Fetching request for requestId: \(requestId)")

            db.collection("requests").document(requestId).getDocument { snapshot, error in
                if let error = error {
                    print("Error fetching request: \(error.localizedDescription)")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else {
                    print("No request found for ID: \(requestId)")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }

                // Attempt to map
                if let request = Request(document: snapshot) {
                    print("Request successfully fetched and mapped.")
                    DispatchQueue.main.async { completion(request) }
                } else {
                    print("Failed to map document data to Request model.")
                    DispatchQueue.main.async { completion(nil) }
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
                    //print("Shared data:", data)  // You can print it or use it as needed
                    
                    completion(.success(data))  // Return the data
                } else {
                    completion(.failure(NSError(domain: "FirestoreError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Document not found."])))
                }
            }
        }
        
    }
