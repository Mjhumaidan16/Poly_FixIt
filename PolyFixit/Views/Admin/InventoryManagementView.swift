//
// InventoryManagementView.swift
// PolyFixit
//
// Created by Manus AI on 2025/12/07.
//

import SwiftUI

struct InventoryManagementView: View {
    @EnvironmentObject var dataService: DataService

    var body: some View {
        List {
            Section(header: Text("Inventory Items")) {
                ForEach(dataService.inventory) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.headline)
                            Text("Category: \(item.category)")
                                .font(.subheadline)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Stock: \(item.currentQuantity)")
                                .foregroundColor(item.currentQuantity <= item.minimumThreshold ? .red : .primary)
                            Text("Min: \(item.minimumThreshold)")
                                .font(.caption)
                        }
                    }
                }
            }

            Section(header: Text("Actions")) {
                NavigationLink("Add New Item (Placeholder)") {
                    Text("Add Inventory Item Form")
                }
                NavigationLink("Generate Inventory Report (Placeholder)") {
                    Text("Report Generation View")
                }
            }
        }
        .navigationTitle("Inventory Management")
    }
}

#Preview {
    InventoryManagementView()
        .environmentObject(DataService())
}
