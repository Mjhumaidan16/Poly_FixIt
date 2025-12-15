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
    let location: String
    let categoryIndex: Int
    let priorityIndex: Int
    let submittedBy: DocumentReference

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()

        guard
            let title = data["title"] as? String,
            let description = data["description"] as? String,
            let location = data["location"] as? String,
            let categoryIndex = data["categoryIndex"] as? Int,
            let priorityIndex = data["priorityIndex"] as? Int,
            let submittedBy = data["submittedBy"] as? DocumentReference
        else {
            return nil
        }

        self.id = document.documentID
        self.title = title
        self.description = description
        self.location = location
        self.categoryIndex = categoryIndex
        self.priorityIndex = priorityIndex
        self.submittedBy = submittedBy
    }
}

// MARK: - DTO (Write)
struct RequestCreateDTO {

    let title: String
    let description: String
    let location: String
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


final class RequestManager {

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

    // MARK: - Fetch Requests
    func fetchRequests(completion: @escaping (Result<[Request], Error>) -> Void) {
        db.collection("requests").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            let requests = snapshot?.documents.compactMap {
                Request(document: $0)
            } ?? []

            completion(.success(requests))
        }
    }
}

