//
// RepairRequestFormView.swift
// PolyFixit
//
// Created by Manus AI on 2025/12/07.
//

import SwiftUI

struct RepairRequestFormView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    @State private var category: String = "Technical"
    @State private var problemDescription: String = ""
    @State private var location: String = ""
    @State private var priority: RequestPriority = .moderate
    @State private var imageURL: String = "" // Placeholder for image upload
    @State private var showingAlert = false
    @State private var alertMessage = ""

    let categories = ["Technical", "Physical", "Plumbing", "Electrical", "Other"]
    let priorities: [RequestPriority] = [.urgent, .moderate, .notice]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Problem Details")) {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) {
                            Text($0)
                        }
                    }

                    TextEditor(text: $problemDescription)
                        .frame(height: 100)
                        .border(Color.gray.opacity(0.3))
                        .overlay(
                            Text(problemDescription.isEmpty ? "Problem Description (required)" : "")
                                .foregroundColor(.gray)
                                .padding(.all, 8)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        )

                    Picker("Priority Level", selection: $priority) {
                        ForEach(priorities, id: \.self) {
                            Text($0.rawValue)
                        }
                    }
                }

                Section(header: Text("Location")) {
                    TextField("Location (e.g., Class 20, Building 19)", text: $location)
                }

                Section(header: Text("Image Attachment (Optional)")) {
                    // Placeholder for image capture/upload
                    Button("Capture or Upload Image") {
                        // TODO: Implement image capture/upload logic
                        alertMessage = "Image upload feature is a placeholder."
                        showingAlert = true
                    }
                    .foregroundColor(.blue)
                }

                Button("Submit Request") {
                    submitRequest()
                }
                .disabled(!isFormValid)
            }
            .navigationTitle("New Repair Request")
            .alert("Submission Status", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    var isFormValid: Bool {
        !problemDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitRequest() {
        guard let submitterID = authManager.currentUserID else {
            alertMessage = "Error: User not logged in."
            showingAlert = true
            return
        }

        // In a real app, we would check for duplicates here (as per doc)
        // For the skeleton, we create a new request with a unique ID
        let newRequest = RepairRequest(
            id: "R\(Int.random(in: 1000...9999))",
            submitterID: submitterID,
            category: category,
            problemDescription: problemDescription,
            location: location,
            priority: priority,
            imageURL: imageURL.isEmpty ? nil : imageURL
        )

        dataService.submitNewRequest(request: newRequest)
        alertMessage = "Your repair request has been submitted successfully! ID: \(newRequest.id)"
        showingAlert = true

        // Reset form
        problemDescription = ""
        location = ""
        priority = .moderate
        imageURL = ""
    }
}

#Preview {
    RepairRequestFormView()
        .environmentObject(AuthManager())
        .environmentObject(DataService())
}
