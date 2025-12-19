import UIKit
import FirebaseAuth

class PasswordResetViewController: UIViewController {

    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var emailTextField: UITextField!  // Email text field for user input
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Initially, clear the status label
        statusLabel.text = ""}
    
    @IBAction func resetPasswordButtonTapped(_ sender: UIButton) {
        // Ensure email is entered
        guard let email = emailTextField.text, !email.isEmpty else {
            statusLabel.text = "Please enter a valid email address."
            return
        }

        // Step 1: Attempt to create a temporary user with the email
        attemptTemporarySignUp(withEmail: email) { error in
            if let error = error as NSError? {
                // Step 2: Email already exists in Firebase (error code indicates this)
                if let authErrorCode = AuthErrorCode(rawValue: error.code),
                   authErrorCode == .emailAlreadyInUse {
                    // Email exists, send the password reset email
                    self.sendResetPasswordEmail(to: email)
                } else {
                    // Handle other errors (if any)
                    self.statusLabel.text = "Error: \(error.localizedDescription)"
                }
            } else {
                // Step 3: Email doesn't exist, delete the temporary account
                self.deleteTemporaryAccount { success in
                    if success {
                        self.statusLabel.text = "Email is not registered. Please contact the admin to create an account."
                    } else {
                        self.statusLabel.text = "Error: Failed to delete the temporary account."
                    }
                }
            }
        }
    }
    
    // Attempt to sign up with the provided email (temporary sign-up)
    func attemptTemporarySignUp(withEmail email: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: "temporaryPassword123") { authResult, error in
            if let error = error {
                // If error is due to the email being in use, return that
                completion(error)
            } else {
                // Account was created successfully (email not registered), delete it
                completion(nil)
            }
        }
    }

    // Delete the temporary account (if email is not registered)
    func deleteTemporaryAccount(completion: @escaping (Bool) -> Void) {
        if let currentUser = Auth.auth().currentUser {
            currentUser.delete { error in
                if let error = error {
                    print("Error deleting temporary account: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        } else {
            completion(false)
        }
    }
    
    // Function to send a password reset email via Firebase Auth
    func sendResetPasswordEmail(to email: String) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            DispatchQueue.main.async {
                if let error = error {
                    // Show error if the reset email failed
                    self.statusLabel.text = "Error: \(error.localizedDescription)"
                } else {
                    // Success, notify the user
                    self.statusLabel.text = "A password reset link has been sent to your email."
                }
            }
        }
    }
}
