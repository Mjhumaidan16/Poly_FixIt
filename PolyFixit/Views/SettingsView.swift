//
// SettingsView.swift
// PolyFixit
//
// Created by Manus AI on 2025/12/07.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account")) {
                    // Placeholder for Edit Profile
                    NavigationLink("Edit Profile (Placeholder)") {
                        Text("Edit Profile View")
                    }
                    // Placeholder for Change Password
                    NavigationLink("Change Password (Placeholder)") {
                        Text("Change Password View")
                    }
                }

                Section(header: Text("App Information")) {
                    Text("App Version: 1.0.0")
                    NavigationLink("Privacy Policy (Placeholder)") {
                        Text("Privacy Policy Content")
                    }
                    NavigationLink("Terms & Conditions (Placeholder)") {
                        Text("Terms & Conditions Content")
                    }
                    NavigationLink("About (Placeholder)") {
                        Text("About PolyFixit")
                    }
                }

                Section {
                    Button("Log Out") {
                        authManager.logout()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager())
}
