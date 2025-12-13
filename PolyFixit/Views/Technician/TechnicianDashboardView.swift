//
// TechnicianDashboardView.swift
// PolyFixit
//
// Created by Manus AI on 2025/12/07.
//

import SwiftUI

struct TechnicianDashboardView: View {
    var body: some View {
        TabView {
            // 1. Assigned Tasks (Landing Page)
            TechnicianTasksView()
                .tabItem {
                    Label("Tasks", systemImage: "list.bullet.clipboard.fill")
                }

            // 2. Schedule Overview (Calendar View)
            NavigationView {
                Text("Technician Schedule Overview (Calendar View Placeholder)")
                    .navigationTitle("My Schedule")
            }
            .tabItem {
                Label("Schedule", systemImage: "calendar")
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
    TechnicianDashboardView()
        .environmentObject(AuthManager())
        .environmentObject(DataService())
}
