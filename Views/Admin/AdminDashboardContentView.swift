//
// AdminDashboardContentView.swift
// PolyFixit
//
// Created by Manus AI on 2025/12/07.
//

import SwiftUI

struct AdminDashboardContentView: View {
    @EnvironmentObject var dataService: DataService

    var totalRequests: Int { dataService.requests.count }
    var pendingRequests: Int { dataService.requests.filter { $0.status == .notAssigned || $0.status == .assigned || $0.status == .inProgress }.count }
    var completedRequests: Int { dataService.requests.filter { $0.status == .done }.count }
    var lowStockItems: Int { dataService.inventory.filter { $0.currentQuantity <= $0.minimumThreshold }.count }

    var body: some View {
        List {
            Section(header: Text("Overview")) {
                HStack {
                    Text("Total Requests")
                    Spacer()
                    Text("\(totalRequests)")
                }
                HStack {
                    Text("Pending Requests")
                    Spacer()
                    Text("\(pendingRequests)")
                        .foregroundColor(.orange)
                }
                HStack {
                    Text("Completed Requests")
                    Spacer()
                    Text("\(completedRequests)")
                        .foregroundColor(.green)
                }
            }

            Section(header: Text("Analytics (Placeholder)")) {
                Text("Bar Chart: Total number of repair requests submitted")
                Text("Line Graph: Resolution Time")
                Text("Stacked Column Chart: Location-Based Request Volume")
            }

            Section(header: Text("Alerts")) {
                HStack {
                    Text("Low Stock Inventory Items")
                    Spacer()
                    Text("\(lowStockItems)")
                        .foregroundColor(lowStockItems > 0 ? .red : .green)
                }
                // Placeholder for Duplicate Requests
                NavigationLink("Duplicate Requests for Review (Placeholder)") {
                    Text("Duplicate Requests List")
                }
            }
        }
        .navigationTitle("Admin Dashboard")
    }
}

#Preview {
    AdminDashboardContentView()
        .environmentObject(DataService())
}
