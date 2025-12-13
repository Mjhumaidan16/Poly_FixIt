//
// LoginView.swift
// PolyFixit
//
// Created by Manus AI on 2025/12/07.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authManager: AuthManager
    @State private var username = ""
    @State private var password = ""
    @State private var loginFailed = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("PolyFixit")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 40)

                TextField("Username or Email", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if loginFailed {
                    Text("Incorrect email or password. please try again.")
                        .foregroundColor(.red)
                }

                Button("Sign In") {
                    if authManager.login(username: username, password: password) {
                        loginFailed = false
                    } else {
                        loginFailed = true
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)

                HStack {
                    Text("Don't have an account?")
                    NavigationLink("Sign Up") {
                        RegistrationView(authManager: authManager)
                    }
                }

                Button("Forgot Password?") {
                    // TODO: Implement forgot password logic
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            .padding()
            .navigationTitle("Login")
        }
    }
}

#Preview {
    LoginView(authManager: AuthManager())
}
