//
// TechnicianManagementView.swift
// PolyFixit
//
// Created by Manus AI on 2025/12/07.
//

import SwiftUI

struct TechnicianManagementView: View {
    @EnvironmentObject var dataService: DataService

    var body: some View {
        List {
            Section(header: Text("Technician List")) {
                ForEach(dataService.technicians, id: \.id) { technician in
                    HStack {
                        Text(technician.username)
                        Spacer()
                        Text("Status: Free (Placeholder)")
                            .foregroundColor(.green)
                    }
                }
            }

            Section(header: Text("Actions")) {
                NavigationLink("Create New Technician Account (Placeholder)") {
                    Text("Technician Account Creation Form")
                }
                NavigationLink("Assign Task (Placeholder)") {
                    Text("Task Assignment View")
                }
            }
        }
        .navigationTitle("Technician Management")
    }
}

#Preview {
    TechnicianManagementView()
        .environmentObject(DataService())
}
