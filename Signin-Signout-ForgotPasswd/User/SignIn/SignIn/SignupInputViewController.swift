import UIKit
import FirebaseAuth

class SignupInputViewController: UIViewController {
    
    // Outlets
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var phoneTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var statusLabel: UILabel!
    
    // Action for Continue button
    @IBAction func continueButtonTapped(_ sender: UIButton) {
        
        // Check if all text fields are filled
        guard let name = nameTextField.text, !name.isEmpty,
              let phone = phoneTextField.text, !phone.isEmpty,
              let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(message: "Please fill in all fields.")
            return
        }
        
        // Validate name (must contain at least two words)
        guard isValidName(name) else {
            showAlert(message: "Please enter a valid name with at least two words.")
            return
        }
        
        // Validate phone number (only digits)
        guard isValidPhoneNumber(phone) else {
            showAlert(message: "Please enter a valid phone number with digits only.")
            return
        }
        
        // Validate email format
        guard isValidEmail(email) else {
            showAlert(message: "Please enter a valid email address.")
            return
        }
        
        // Validate password (at least 8 characters, one uppercase letter, one number, one special character)
        guard isValidPassword(password) else {
            showAlert(message: "Password must be at least 8 characters, include one uppercase letter, one number, and one special character.")
            return
        }
        
        // Attempt to create the user in Firebase Authentication
        createUserInFirebase(email: email, password: password)
    }
    
    // Create a user in Firebase Authentication
    func createUserInFirebase(email: String, password: String) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] (authResult, error) in
            guard let self = self else { return }
            
            if let error = error {
                // If the error is 'Email already in use', alert the user and suggest login or password reset
                if let authError = error as NSError?, authError.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                    self.statusLabel.text = "Email already in use."
                    self.showAlert(message: "This email is already registered. Please sign in or use the forgot password feature.")
                } else {
                    // Handle other errors
                    self.statusLabel.text = "Error: \(error.localizedDescription)"
                    self.showAlert(message: "Error: \(error.localizedDescription)")
                }
                return
            }
            
            // Delete the user from Firebase Authentication
            self.deleteUserFromAuth(email: email)
            
            // If user is successfully created, show success message and delete user
            self.statusLabel.text = "Signup successful!"
            
            // Show alert and navigate after it's dismissed
            self.navigateToOTPVerification() // Navigate after the alert is dismissed
            
        }
    }
    
    // Delete the created user from Firebase Auth using email
    func deleteUserFromAuth(email: String) {
        // Find the current user by email
        guard let currentUser = Auth.auth().currentUser else {
            self.showAlert(message: "No user found to delete.")
            return
        }
        
        // Only delete if the current user's email matches the one provided
        if currentUser.email == email {
            currentUser.delete { error in
                if let error = error {
                    self.showAlert(message: "Failed to delete user: \(error.localizedDescription)")
                } else {
                    self.statusLabel.text = "User successfully deleted."
                }
            }
        } else {
            self.showAlert(message: "The email does not match the current user's email.")
        }
    }
    
    // Validate name (must contain at least two words)
    func isValidName(_ name: String) -> Bool {
        let nameComponents = name.split(separator: " ")
        return nameComponents.count >= 2 // Name should have at least two words
    }
    
    // Validate phone number (must contain digits only)
    func isValidPhoneNumber(_ phone: String) -> Bool {
        let phoneRegex = "^[0-9]+$"  // Only digits allowed
        let phoneTest = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phoneTest.evaluate(with: phone)
    }
    
    // Validate email format using regular expression
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailTest.evaluate(with: email)
    }
    
    // Validate password format (at least 8 characters, one uppercase letter, one number, one special character)
    func isValidPassword(_ password: String) -> Bool {
        let passwordRegex = "^(?=.*[A-Z])(?=.*[a-z])(?=.*\\d)(?=.*[@$!%*?&_])[A-Za-z\\d@$!%*?&_]{8,}$"
        let passwordTest = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        return passwordTest.evaluate(with: password)
    }
    
    // Function to show an alert
    func showAlert(message: String, completion: @escaping () -> Void = {}) {
        let alert = UIAlertController(title: "Signup", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            completion()  // Call the completion handler after the alert is dismissed
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    // Navigate to OTPVerificationViewController
    func navigateToOTPVerification() {
        // Ensure the navigation controller is available
        if let navigationController = self.navigationController {
            // Create OTPVerificationViewController
            if let otpVC = storyboard?.instantiateViewController(withIdentifier: "OTPVerificationViewController") as? OTPVerificationViewController {
                otpVC.name = nameTextField.text
                otpVC.phone = phoneTextField.text
                otpVC.email = emailTextField.text
                otpVC.password = passwordTextField.text
                
                // Push the OTPVerificationViewController onto the navigation stack
                navigationController.pushViewController(otpVC, animated: true)
            }
        }
    }
}
