//
// TechnicianTasksView.swift
// PolyFixit
//
// Created by Manus AI on 2025/12/07.
//

import SwiftUI

struct TechnicianTasksView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService

    var assignedRequests: [RepairRequest] {
        dataService.getAssignedRequests(for: authManager.currentUserID ?? "")
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(assignedRequests) { request in
                    NavigationLink(destination: TechnicianTaskDetailView(request: request)) {
                        VStack(alignment: .leading) {
                            Text(request.problemDescription)
                                .font(.headline)
                            HStack {
                                Text("Status: \(request.status.rawValue)")
                                    .foregroundColor(statusColor(request.status))
                                Spacer()
                                Text("ID: \(request.id)")
                                    .font(.caption)
                            }
                            Text("Location: \(request.location)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Assigned Tasks")
        }
    }

    private func statusColor(_ status: RequestStatus) -> Color {
        switch status {
        case .assigned: return .blue
        case .inProgress: return .purple
        default: return .gray
        }
    }
}

struct TechnicianTaskDetailView: View {
    @EnvironmentObject var dataService: DataService
    @State var request: RepairRequest
    @State private var showingInventorySheet = false

    var body: some View {
        Form {
            Section(header: Text("Task Details")) {
                Text("ID: \(request.id)")
                Text("Status: \(request.status.rawValue)")
                Text("Category: \(request.category)")
                Text("Location: \(request.location)")
                Text("Priority: \(request.priority.rawValue)")
                Text("Description: \(request.problemDescription)")
                Text("Submitted: \(request.dateSubmitted, style: .date)")
            }

            Section(header: Text("Actions")) {
                if request.status == .assigned {
                    Button("Start Work (Set to In Progress)") {
                        updateStatus(to: .inProgress)
                    }
                } else if request.status == .inProgress {
                    Button("Mark as Done") {
                        showingInventorySheet = true
                    }
                    .foregroundColor(.green)
                }
            }
        }
        .navigationTitle("Task \(request.id)")
        .sheet(isPresented: $showingInventorySheet) {
            InventoryUsageView(request: $request)
        }
    }

    private func updateStatus(to newStatus: RequestStatus) {
        request.status = newStatus
        dataService.updateRequest(request: request)
    }
}

struct InventoryUsageView: View {
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) var dismiss
    @Binding var request: RepairRequest
    @State private var selectedItem: InventoryItem?
    @State private var quantityUsed: Int = 1
    @State private var workNote: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Proof of Work")) {
                    // Placeholder for image upload
                    Button("Upload Proof Image (Placeholder)") {
                        // TODO: Implement image upload
                    }
                    TextEditor(text: $workNote)
                        .frame(height: 100)
                        .border(Color.gray.opacity(0.3))
                        .overlay(
                            Text(workNote.isEmpty ? "Work Done Note" : "")
                                .foregroundColor(.gray)
                                .padding(.all, 8)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        )
                }

                Section(header: Text("Inventory Used")) {
                    Picker("Select Item", selection: $selectedItem) {
                        Text("None").tag(nil as InventoryItem?)
                        ForEach(dataService.inventory) { item in
                            Text("\(item.name) (\(item.currentQuantity) in stock)").tag(item as InventoryItem?)
                        }
                    }

                    if selectedItem != nil {
                        Stepper("Quantity Used: \(quantityUsed)", value: $quantityUsed, in: 1...10) // Max 10 for demo
                    }
                }

                Button("Submit & Complete Task") {
                    completeTask()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .navigationTitle("Complete Task \(request.id)")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func completeTask() {
        // 1. Update Inventory
        if var item = selectedItem {
            item.currentQuantity -= quantityUsed
            dataService.updateInventory(item: item)
        }

        // 2. Update Request Status
        request.status = .done
        request.dateResolved = Date()
        dataService.updateRequest(request: request)

        // 3. Dismiss
        dismiss()
    }
}

#Preview {
    TechnicianTasksView()
        .environmentObject(AuthManager())
        .environmentObject(DataService())
}
