import UIKit
import FirebaseAuth

class SignupInputViewController: UIViewController {
    
    // Outlets
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var phoneTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    //@IBOutlet weak var statusLabel: UILabel!

    // We generate OTP here and pass it to OTPVerificationViewController.
    
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
        
        // Generate OTP, send it by email, then proceed to OTP verification screen.
        // (User creation happens only AFTER OTP verification.)
        sendSignupOTPAndNavigate(name: name, phone: phone, email: email, password: password)
    }

    /// Generates an OTP, emails it, then navigates to OTPVerificationViewController.
    private func sendSignupOTPAndNavigate(name: String, phone: String, email: String, password: String) {

        DispatchQueue.main.async {
            //self.statusLabel.text = "Checking account..."
        }

        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }

            // If createUser failed, decide whether it's "exists" or a real error
            if let err = error as NSError? {
                let code = AuthErrorCode(_bridgedNSError: err)?.code

                DispatchQueue.main.async {
                    switch code {
                    case .emailAlreadyInUse:
                       //self.statusLabel.text = "Email already in use."
                        self.showAlert(message: "This email is already registered. Please sign in or use the forgot password feature.")
                    default:
                        //self.statusLabel.text = "\(err.localizedDescription)"
                        self.showAlert(message: "\(err.localizedDescription)")
                    }
                }
                return
            }

            // Created successfully -> user is now signed in as that new user
            guard let createdUser = result?.user else {
                DispatchQueue.main.async {
                    //self.statusLabel.text = "Failed to create user."
                    self.showAlert(message: "Failed to create user.")
                }
                return
            }

            DispatchQueue.main.async {
               // self.statusLabel.text = "Cleaning up..."
            }

            // Delete the newly created user so we can proceed with OTP flow
            createdUser.delete { [weak self] deleteError in
                guard let self = self else { return }

                if let deleteError = deleteError {
                    DispatchQueue.main.async {
                        //self.statusLabel.text = "\(deleteError.localizedDescription)"
                        self.showAlert(message: "Could not verify signup at this time. Please try again.\n(\(deleteError.localizedDescription))")
                    }
                    return
                }

                // Important: sign out to clear auth state after deletion
                do { try Auth.auth().signOut() } catch {
                    // Not fatal, but log if you want
                }

                // Now continue with OTP as usual
                let otp = OTPManager.shared.generateOTP()
                DispatchQueue.main.async {
                    //self.statusLabel.text = "Sending OTP..."
                }

                let emailSender = EmailSender()
                emailSender.sendOTP(to: email, otp: otp) { success in
                    DispatchQueue.main.async {
                        if success {
                            //self.statusLabel.text = "OTP sent to \(email)"
                            self.navigateToOTPVerification(
                                name: name,
                                phone: phone,
                                email: email,
                                password: password,
                                otp: otp
                            )
                        } else {
                            //self.statusLabel.text = "Failed to send OTP"
                            self.showAlert(message: "Failed to send OTP to email. Please try again.")
                        }
                    }
                }
            }
        }
    }

    // Navigate to OTPVerificationViewController
    private func navigateToOTPVerification(name: String, phone: String, email: String, password: String, otp: String) {

        let sb = self.storyboard ?? UIStoryboard(name: "Main", bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: "OTPVerificationViewController")

        // ✅ Ensure the storyboard scene Custom Class is OTPVerificationViewController
        guard let otpVC = vc as? OTPVerificationViewController else {
            self.showAlert(message: "OTP screen is not configured correctly in storyboard (Custom Class mismatch).")
            return
        }

        otpVC.name = name
        otpVC.phone = phone
        otpVC.email = email
        otpVC.password = password
        otpVC.generatedOTP = otp

        if let nav = self.navigationController {
            nav.pushViewController(otpVC, animated: true)
        } else {
            // ✅ If you're not inside a UINavigationController, present instead
            otpVC.modalPresentationStyle = .fullScreen
            self.present(otpVC, animated: true)
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
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Signup", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                completion()  // Call the completion handler after the alert is dismissed
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
}
