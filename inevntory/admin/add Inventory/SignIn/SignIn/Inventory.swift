import Foundation
import FirebaseFirestore

// MARK: - Inventory Model (Read)
struct InventoryItem {
    let itemId: String
    let itemName: String
    let category: [String]
    let selectedCategory: String?
    let imageUrl: String?
    let quantityAvailable: Int
    let minimumThreshold: Int
    let usageHistory: [[Any]] // Array of arrays: [Timestamp, Number, Reference]
    let createdAt: Timestamp

    init?(document: DocumentSnapshot) {
        let data = document.data() ?? [:]

        guard
            let itemName = data["itemName"] as? String,
            let itemId = data["itemId"] as? String,
            let category = data["category"] as? [String],
            let quantityAvailable = data["quantityAvailable"] as? Int,
            let minimumThreshold = data["minimumThreshold"] as? Int,
            let createdAt = data["createdAt"] as? Timestamp
        else {
            print("Error: Missing required fields in InventoryItem")
            return nil
        }

        self.itemId = itemId
        self.itemName = itemName
        self.category = category
        self.selectedCategory = data["selectedCategory"] as? String
        self.imageUrl = data["imageUrl"] as? String
        self.quantityAvailable = quantityAvailable
        self.minimumThreshold = minimumThreshold
        self.usageHistory = data["usageHistory"] as? [[Any]] ?? []
        self.createdAt = createdAt
    }
}
// MARK: - DTO (Write)
struct InventoryCreateDTO {
    let itemId: String
    let itemName: String
    let category: [String]
    let selectedCategory: String?
    let imageUrl: String?
    let quantityAvailable: Int
    let minimumThreshold: Int
    let usageHistory: [[Any]]
    let createdAt: Timestamp

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["itemId"] = itemId
        dict["itemName"] = itemName
        dict["category"] = category
        if let selectedCategory { dict["selectedCategory"] = selectedCategory }
        if let imageUrl { dict["imageUrl"] = imageUrl }
        dict["quantityAvailable"] = quantityAvailable
        dict["minimumThreshold"] = minimumThreshold
        dict["usageHistory"] = usageHistory
        dict["createdAt"] = createdAt
        return dict
    }
}


// MARK: - DTO (Edit)
struct InventoryUpdateDTO {
    let itemId: String?
    let itemName: String?
    let category: [String]?
    let selectedCategory: String?
    let imageUrl: String?
    let quantityAvailable: Int?
    let minimumThreshold: Int?
    let usageHistory: [[Any]]?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let itemId { dict["itemId"] = itemId }
        if let itemName { dict["itemName"] = itemName }
        if let category { dict["category"] = category }
        if let selectedCategory { dict["selectedCategory"] = selectedCategory }
        if let imageUrl { dict["imageUrl"] = imageUrl }
        if let quantityAvailable { dict["quantityAvailable"] = quantityAvailable }
        if let minimumThreshold { dict["minimumThreshold"] = minimumThreshold }
        if let usageHistory { dict["usageHistory"] = usageHistory }
        dict["updatedAt"] = Timestamp()
        return dict
    }
}



final class InventoryManager {

    static let shared = InventoryManager()
    private init() {}

    private let db = Firestore.firestore()

    // MARK: - Add Inventory Item
    func addInventory(_ item: InventoryCreateDTO) async throws -> String {
        let docRef = try await db.collection("inventory").addDocument(data: item.toDictionary())
        return docRef.documentID
    }

    // MARK: - Update Inventory Item
    func updateInventory(itemId: String, updateDTO: InventoryUpdateDTO) async throws {
        let docRef = db.collection("inventory").document(itemId)
        try await docRef.updateData(updateDTO.toDictionary())
    }

    // MARK: - Delete Inventory Item
    func deleteInventory(itemId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("inventory").document(itemId).delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: - Fetch Inventory Item by ID
    func fetchInventory(itemId: String, completion: @escaping (InventoryItem?) -> Void) {
        db.collection("inventory").document(itemId).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching inventory: \(error.localizedDescription)")
                completion(nil)
                return
            }
            guard let snapshot = snapshot, snapshot.exists else {
                print("Inventory item not found for ID: \(itemId)")
                completion(nil)
                return
            }
            completion(InventoryItem(document: snapshot))
        }
    }
}
