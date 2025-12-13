//
// MyRequestsView.swift
// PolyFixit
//
// Created by Manus AI on 2025/12/07.
//

import SwiftUI

struct MyRequestsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService

    var body: some View {
        NavigationView {
            List {
                ForEach(dataService.requests.filter { $0.submitterID == authManager.currentUserID ?? "" }) { request in
                    NavigationLink(destination: RequestDetailView(request: request)) {
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
                            Text("Submitted: \(request.dateSubmitted, style: .date)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("My Requests")
        }
    }

    private func statusColor(_ status: RequestStatus) -> Color {
        switch status {
        case .notAssigned: return .orange
        case .assigned: return .blue
        case .inProgress: return .purple
        case .done: return .green
        case .canceled: return .red
        }
    }
}

struct RequestDetailView: View {
    @EnvironmentObject var dataService: DataService
    @State var request: RepairRequest
    @State private var showingCancelAlert = false
    @State private var showingEditSheet = false

    var body: some View {
        Form {
            Section(header: Text("Request Details")) {
                Text("ID: \(request.id)")
                Text("Status: \(request.status.rawValue)")
                    .foregroundColor(statusColor(request.status))
                Text("Category: \(request.category)")
                Text("Location: \(request.location)")
                Text("Priority: \(request.priority.rawValue)")
                Text("Description: \(request.problemDescription)")
                Text("Submitted: \(request.dateSubmitted, style: .date)")
            }

            Section(header: Text("Actions")) {
                // Edit/Cancel only if Not Assigned (as per doc)
                if request.status == .notAssigned {
                    Button("Edit Request") {
                        showingEditSheet = true
                    }
                    Button("Cancel Request") {
                        showingCancelAlert = true
                    }
                    .foregroundColor(.red)
                } else {
                    Text("Modification is disabled as the request is \(request.status.rawValue).")
                        .foregroundColor(.gray)
                }

                // Placeholder for Chat
                Button("Follow-up Chat (Placeholder)") {
                    // TODO: Implement chat view
                }
            }
        }
        .navigationTitle("Request \(request.id)")
        .sheet(isPresented: $showingEditSheet) {
            EditRequestView(request: $request)
        }
        .alert("Cancel Request", isPresented: $showingCancelAlert) {
            Button("Yes, Cancel", role: .destructive) {
                cancelRequest()
            }
            Button("No", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel this request? This action cannot be undone.")
        }
    }

    private func statusColor(_ status: RequestStatus) -> Color {
        switch status {
        case .notAssigned: return .orange
        case .assigned: return .blue
        case .inProgress: return .purple
        case .done: return .green
        case .canceled: return .red
        }
    }

    private func cancelRequest() {
        request.status = .canceled
        dataService.updateRequest(request: request)
    }
}

struct EditRequestView: View {
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) var dismiss
    @Binding var request: RepairRequest

    @State private var category: String
    @State private var problemDescription: String
    @State private var location: String
    @State private var priority: RequestPriority

    let categories = ["Technical", "Physical", "Plumbing", "Electrical", "Other"]
    let priorities: [RequestPriority] = [.urgent, .moderate, .notice]

    init(request: Binding<RepairRequest>) {
        _request = request
        _category = State(initial: request.wrappedValue.category)
        _problemDescription = State(initial: request.wrappedValue.problemDescription)
        _location = State(initial: request.wrappedValue.location)
        _priority = State(initial: request.wrappedValue.priority)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit Details")) {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) {
                            Text($0)
                        }
                    }

                    TextEditor(text: $problemDescription)
                        .frame(height: 100)
                        .border(Color.gray.opacity(0.3))

                    Picker("Priority Level", selection: $priority) {
                        ForEach(priorities, id: \.self) {
                            Text($0.rawValue)
                        }
                    }

                    TextField("Location", text: $location)
                }

                Button("Save Changes") {
                    saveChanges()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .navigationTitle("Edit Request \(request.id)")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveChanges() {
        request.category = category
        request.problemDescription = problemDescription
        request.location = location
        request.priority = priority
        dataService.updateRequest(request: request)
        dismiss()
    }
}

#Preview {
    MyRequestsView()
        .environmentObject(AuthManager())
        .environmentObject(DataService())
}
