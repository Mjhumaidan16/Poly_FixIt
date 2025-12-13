//
// StudentStaffDashboardView.swift
// PolyFixit
//
// Created by Manus AI on 2025/12/07.
//

import SwiftUI

struct StudentStaffDashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService

    var body: some View {
        TabView {
            // 1. Repair Request Submission
            RepairRequestFormView()
                .tabItem {
                    Label("New Request", systemImage: "plus.circle.fill")
                }

            // 2. Request Management (Tracking)
            MyRequestsView()
                .tabItem {
                    Label("My Requests", systemImage: "list.bullet")
                }

            // 3. Settings/Profile
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    StudentStaffDashboardView()
        .environmentObject(AuthManager())
        .environmentObject(DataService())
}
