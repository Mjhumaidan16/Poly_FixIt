import UIKit
import FirebaseAuth

class AdminChangePasswordViewController: UIViewController {

    // -----------------------------
    // IBOutlets: UI elements from storyboard
    // -----------------------------
    @IBOutlet weak var changePasswordTextField: UITextField! // ✅ Added change password text field IBOutlet
    @IBOutlet weak var changePasswordStatusLabel: UILabel! // ✅ Added change password label IBOutlet
    @IBOutlet weak var changePasswordButton: UIButton! // ✅ Added change password button IBOutlet

    // =============================
    // Change Password Button Action
    // =============================
    @IBAction func changePasswordButtonTapped(_ sender: UIButton) {
        guard let newPassword = changePasswordTextField.text, !newPassword.isEmpty else {
            changePasswordStatusLabel.text = "Enter new password"
            removeWarningsAfterDelay()
            return
        }

        // -----------------------------
        // PASSWORD VALIDATION
        // -----------------------------
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

                    // -----------------------------
                    // LOG OUT USER AFTER PASSWORD CHANGE
                    // -----------------------------
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

    // =============================
    // Password Validation Helper
    // =============================
    private func isValidPassword(_ password: String) -> Bool {
        // Minimum 8 characters, 1 uppercase, 1 lowercase, 1 number
        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,}$"
        let passwordPred = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        return passwordPred.evaluate(with: password)
//        return true
    }

    // =============================
    // Helper Methods
    // =============================
    private func removeWarningsAfterDelay() {
        // Remove warnings after 7 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
            self.clearWarnings()
        }
    }

    private func clearWarnings() {
        changePasswordStatusLabel.text = ""
    }
}
