//
// AdminDashboardView.swift
// PolyFixit
//
// Created by Manus AI on 2025/12/07.
//

import SwiftUI

struct AdminDashboardView: View {
    var body: some View {
        TabView {
            // 1. Dashboard with Analytics
            NavigationView {
                AdminDashboardContentView()
            }
            .tabItem {
                Label("Dashboard", systemImage: "chart.bar.fill")
            }

            // 2. Technician Management
            NavigationView {
                TechnicianManagementView()
            }
            .tabItem {
                Label("Technicians", systemImage: "person.3.fill")
            }

            // 3. Inventory Management
            NavigationView {
                InventoryManagementView()
            }
            .tabItem {
                Label("Inventory", systemImage: "shippingbox.fill")
            }

            // 4. Settings/Profile
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    AdminDashboardView()
        .environmentObject(AuthManager())
        .environmentObject(DataService())
}
