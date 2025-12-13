//
// ContentView.swift
// PolyFixit
//
// Created by Manus AI on 2025/12/07.
//

import SwiftUI

struct ContentView: View {
    @StateObject var authManager = AuthManager()
    @StateObject var dataService = DataService() // Initialize DataService here

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                switch authManager.userRole {
                case .admin:
                    AdminDashboardView()
                case .technician:
                    TechnicianDashboardView()
                case .studentStaff:
                    StudentStaffDashboardView()
                case .none:
                    // Should not happen if isAuthenticated is true, but as a fallback
                    LoginView(authManager: authManager)
                }
            } else {
                LoginView(authManager: authManager)
            }
        }
        .environmentObject(authManager) // Make AuthManager available to subviews
        .environmentObject(dataService) // Make DataService available to subviews
        .onAppear {
            // Attempt to restore session on launch
            authManager.restoreSession()
        }
    }
}

#Preview {
    ContentView()
}
