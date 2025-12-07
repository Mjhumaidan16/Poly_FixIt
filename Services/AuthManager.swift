//
//  AuthManager.swift
//  
//
//  Created by BP-36-201-16 on 06/12/2025.
//

import Foundation

enum UserRole: String, Codable {
    case admin
    case technician
    case studentStaff = "student/staff"
}

class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var userRole: UserRole?
    @Published var currentUserID: String?

    // Placeholder for a simple user model
    struct User: Codable {
        let id: String
        let username: String
        let role: UserRole
    }

    // MARK: - Authentication Logic

    func login(username: String, password: String) -> Bool {
        // --- Placeholder for actual authentication logic (e.g., API call) ---
        // Based on the design document, we need to authenticate against a database.
        // For this skeleton, we'll use hardcoded credentials for demonstration.

        if username == "admin" && password == "adminpass" {
            let user = User(id: "A001", username: username, role: .admin)
            completeLogin(with: user)
            return true
        } else if username == "tech" && password == "techpass" {
            let user = User(id: "T001", username: username, role: .technician)
            completeLogin(with: user)
            return true
        } else if username == "student" && password == "studentpass" {
            let user = User(id: "S001", username: username, role: .studentStaff)
            completeLogin(with: user)
            return true
        } else {
            // In a real app, this would be an API call failure
            print("Login failed for user: \(username)")
            return false
        }
    }

    func logout() {
        // In a real app, this would involve invalidating the session token
        isAuthenticated = false
        userRole = nil
        currentUserID = nil
        // Clear stored session data
        UserDefaults.standard.removeObject(forKey: "currentUserID")
        UserDefaults.standard.removeObject(forKey: "userRole")
        print("User logged out.")
    }

    func restoreSession() {
        // Restore session from UserDefaults (placeholder for secure token storage)
        if let storedID = UserDefaults.standard.string(forKey: "currentUserID"),
           let storedRoleString = UserDefaults.standard.string(forKey: "userRole"),
           let storedRole = UserRole(rawValue: storedRoleString) {

            // In a real app, you would validate the session token with the server here
            self.currentUserID = storedID
            self.userRole = storedRole
            self.isAuthenticated = true
            print("Session restored for user ID: \(storedID) with role: \(storedRole.rawValue)")
        }
    }

    // MARK: - Helper

    private func completeLogin(with user: User) {
        self.currentUserID = user.id
        self.userRole = user.role
        self.isAuthenticated = true

        // Save session data (placeholder for secure token storage)
        UserDefaults.standard.set(user.id, forKey: "currentUserID")
        UserDefaults.standard.set(user.role.rawValue, forKey: "userRole")
        print("Login successful for user ID: \(user.id) with role: \(user.role.rawValue)")

        // Session timeout logic (as per design doc: 10-min inactivity)
        // This would typically be handled by a background timer or server-side token expiration.
        // For a skeleton, we'll just add a comment.
        // TODO: Implement 10-minute inactivity logout logic.
    }
}
