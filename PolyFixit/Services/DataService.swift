//
//  DataService.swift
//  
//
//  Created by BP-36-201-16 on 06/12/2025.
//

import Foundation

class DataService: ObservableObject {
    @Published var requests: [RepairRequest] = []
    @Published var inventory: [InventoryItem] = []
    @Published var technicians: [AuthManager.User] = []

    init() {
        // Initialize with mock data
        loadMockData()
    }

    // MARK: - Mock Data Loading

    private func loadMockData() {
        // Mock Technicians
        technicians = [
            AuthManager.User(id: "T001", username: "tech", role: .technician),
            AuthManager.User(id: "T002", username: "plumber", role: .technician),
            AuthManager.User(id: "T003", username: "electrician", role: .technician)
        ]

        // Mock Requests
        requests = [
            RepairRequest(id: "R001", submitterID: "S001", category: "Technical", problemDescription: "Computer in Lab 101 is not turning on.", location: "Lab 101, Building 10", priority: .urgent, status: .assigned),
            RepairRequest(id: "R002", submitterID: "S001", category: "Physical", problemDescription: "Broken chair in Class 20.", location: "Class 20, Building 19", priority: .moderate, status: .inProgress),
            RepairRequest(id: "R003", submitterID: "S002", category: "Physical", problemDescription: "Broken chair in Class 20.", location: "Class 20, Building 19", priority: .notice, status: .notAssigned, isDuplicate: true, masterTicketID: "R002"),
            RepairRequest(id: "R004", submitterID: "S003", category: "Plumbing", problemDescription: "Leaky faucet in the staff bathroom.", location: "Staff Bathroom, Building 5", priority: .urgent, status: .done, dateResolved: Date().addingTimeInterval(-86400 * 2)) // 2 days ago
        ]
        // Assign technician to R001 and R002
        if var r1 = requests.first(where: { $0.id == "R001" }) {
            r1.technicianID = "T001"
            requests[requests.firstIndex(where: { $0.id == "R001" })!] = r1
        }
        if var r2 = requests.first(where: { $0.id == "R002" }) {
            r2.technicianID = "T002"
            requests[requests.firstIndex(where: { $0.id == "R002" })!] = r2
        }

        // Mock Inventory
        inventory = [
            InventoryItem(id: "I001", name: "Monitor Cable", category: "Technical", currentQuantity: 50, minimumThreshold: 10),
            InventoryItem(id: "I002", name: "Chair Leg", category: "Physical", currentQuantity: 5, minimumThreshold: 5),
            InventoryItem(id: "I003", name: "Faucet Washer", category: "Plumbing", currentQuantity: 100, minimumThreshold: 20)
        ]
    }

    // MARK: - Request Management

    func submitNewRequest(request: RepairRequest) {
        // In a real app, this would be an API call to save to the database
        requests.append(request)
        print("New request submitted: \(request.id)")
    }

    func updateRequest(request: RepairRequest) {
        if let index = requests.firstIndex(where: { $0.id == request.id }) {
            requests[index] = request
            print("Request updated: \(request.id)")
        }
    }

    func getRequests(for userID: String) -> [RepairRequest] {
        return requests.filter { $0.submitterID == userID }
    }

    func getAssignedRequests(for technicianID: String) -> [RepairRequest] {
        return requests.filter { $0.technicianID == technicianID && $0.status != .done && $0.status != .canceled }
    }

    // MARK: - Inventory Management

    func updateInventory(item: InventoryItem) {
        if let index = inventory.firstIndex(where: { $0.id == item.id }) {
            inventory[index] = item
            print("Inventory updated for item: \(item.name)")
        }
    }

    func getInventory() -> [InventoryItem] {
        return inventory
    }

    // MARK: - Technician Management

    func getTechnicians() -> [AuthManager.User] {
        return technicians
    }
}
