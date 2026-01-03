import UIKit
import FirebaseAuth

class AdminChangePasswordViewController: UIViewController {


    @IBOutlet weak var changePasswordTextField: UITextField! //Added change password text field IBOutlet
    @IBOutlet weak var changePasswordStatusLabel: UILabel! //Added change password label IBOutlet
    @IBOutlet weak var changePasswordButton: UIButton! //Added change password button IBOutlet

 
    @IBAction func changePasswordButtonTapped(_ sender: UIButton) {
        guard let newPassword = changePasswordTextField.text, !newPassword.isEmpty else {
            changePasswordStatusLabel.text = "Enter new password"
            removeWarningsAfterDelay()
            return
        }

   
        if !isValidPassword(newPassword) {
            changePasswordStatusLabel.text = "Password must meet the requirments"
            removeWarningsAfterDelay()
            return
        }

        // Get current logged in user
        if let currentUser = Auth.auth().currentUser {
            currentUser.updatePassword(to: newPassword) { error in
                if let error = error {
                    print("Error updating password:", error.localizedDescription)
                    self.changePasswordStatusLabel.text = "Password update failed"
                    self.removeWarningsAfterDelay()
                } else {
                    print("Password updated successfully")
                    self.changePasswordStatusLabel.text = "Password updated"

               
                    // Remove saved admin data
                    UserDefaults.standard.removeObject(forKey: "loggedInAdmin")
                    
                    // Sign out from Firebase
                    do {
                        try Auth.auth().signOut()
                        print("User logged out after password change")
                        self.changePasswordStatusLabel.text = "Password changed. Logged out."
                    } catch {
                        print("Firebase sign out error:", error.localizedDescription)
                        self.changePasswordStatusLabel.text = "Password changed. Logout failed."
                    }

                    self.removeWarningsAfterDelay()
                }
            }
        } else {
            changePasswordStatusLabel.text = "No user logged in"
            removeWarningsAfterDelay()
        }
    }


    private func isValidPassword(_ password: String) -> Bool {
        // Minimum 8 characters, 1 uppercase, 1 lowercase, 1 number
        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,}$"
        let passwordPred = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        return passwordPred.evaluate(with: password)
    }

   
    private func removeWarningsAfterDelay() {
        // Remove warnings after 7 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
            self.clearWarnings()
        }
    }

    private func clearWarnings() {
        changePasswordStatusLabel.text = ""
    }
    
    
        @IBAction func logoutButtonTapped(_ sender: UIButton) {
            UserDefaults.standard.removeObject(forKey: "loggedInAdmin")
    
            do {
                try Auth.auth().signOut()
                goToLogin()
                print("Logout button tapped")
            } catch {
                print("Firebase sign out error:", error.localizedDescription)
            }
        }
    
    
    // Logout user and clear data
    private func logoutUser() {
        // Clear saved admin data from UserDefaults
        UserDefaults.standard.removeObject(forKey: "loggedInAdmin")
        
        // Log out from Firebase Authentication
        do {
            try Auth.auth().signOut()
            print("User logged out successfully")
        } catch {
            print("Firebase sign out error:", error.localizedDescription)
        }
    }
    
    
    private func goToLogin() {
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first(where: { $0.isKeyWindow })
        else { return }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let loginVC = storyboard.instantiateViewController(withIdentifier: "AdminLoginViewController")
        window.rootViewController = loginVC
        window.makeKeyAndVisible()
    }
}
