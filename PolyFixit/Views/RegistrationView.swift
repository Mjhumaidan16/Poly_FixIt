//
// RegistrationView.swift
// PolyFixit
//
// Created by Manus AI on 2025/12/07.
//

import SwiftUI

struct RegistrationView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var role: UserRole = .studentStaff // Only student/staff can register
    @State private var registrationSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Account")
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom, 20)

            TextField("Full Name", text: $fullName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.words)

            TextField("University Email Address", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Picker("User Role", selection: $role) {
                Text("Student").tag(UserRole.studentStaff)
                Text("Staff").tag(UserRole.studentStaff)
            }
            .pickerStyle(.segmented)
            .disabled(true) // As per doc, only student/staff can register here

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            Button("Sign Up") {
                registerUser()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)

            if registrationSuccess {
                Text("Registration successful! Please sign in.")
                    .foregroundColor(.green)
                    .onAppear {
                        // Automatically dismiss after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            dismiss()
                        }
                    }
            }
        }
        .padding()
        .navigationTitle("Sign Up")
    }

    private func registerUser() {
        // --- Placeholder for actual registration logic ---
        // 1. Validation (as per doc: all fields, email format, password security)
        guard !fullName.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessage = "All fields are required."
            return
        }

        // Simple email format check
        guard email.contains("@") else {
            errorMessage = "Invalid email format."
            return
        }

        // Simple password security check (min 8 chars, letters and numbers)
        guard password.count >= 8, password.rangeOfCharacter(from: .letters) != nil, password.rangeOfCharacter(from: .decimalDigits) != nil else {
            errorMessage = "Password must be at least 8 characters and contain letters and numbers."
            return
        }

        // 2. System creates the user account (placeholder)
        // In a real app, this would be an API call to create the user in the database.
        print("Attempting to register user: \(fullName) with email: \(email)")

        // Assuming success for the skeleton
        registrationSuccess = true
        errorMessage = nil
    }
}

#Preview {
    RegistrationView(authManager: AuthManager())
}
