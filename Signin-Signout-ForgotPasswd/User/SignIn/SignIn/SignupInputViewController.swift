import UIKit
import SwiftSMTP

class SignupInputViewController: UIViewController {
    
    // Outlets
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var phoneTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var statusLabel: UILabel!
    
    // Temporary memory storage for user input
    var userData: [String: String] = [:]
    var currentOTP: String?
    
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
        
        // Validate email format
        guard isValidEmail(email) else {
            showAlert(message: "Please enter a valid email address.")
            return
        }
        
        // Store user data temporarily in memory
        userData["name"] = name
        userData["phone"] = phone
        userData["email"] = email
        userData["password"] = password
        
        // Send OTP to email
        sendOTP(to: email)
    }
    
    // Function to send OTP to the email
    func sendOTP(to email: String) {
        // Generate OTP
        let otp = generateOTP()
        
        // Send OTP using EmailSender class
        sendEmailOTP(to: email, otp: otp) { success in
            DispatchQueue.main.async {
                if success {
                    self.statusLabel.text = "OTP sent to \(email)"
                    
                    // Store OTP temporarily for verification on the next screen
                    self.currentOTP = otp
                    
                    // Navigate to OTP verification screen
                    guard let nav = self.navigationController else { return }
                    if let otpVC = self.storyboard?.instantiateViewController(withIdentifier: "OTPVerificationViewController") as? OTPVerificationViewController {
                        otpVC.email = email // Pass email to OTPVerificationViewController
                        otpVC.otp = otp     // Pass OTP to OTPVerificationViewController
                        otpVC.userData = self.userData // Pass user data
                        nav.pushViewController(otpVC, animated: true)
                    }
                } else {
                    self.statusLabel.text = "Failed to send OTP"
                }
            }
        }
    }
    
    // Generate OTP
    func generateOTP() -> String {
        let otp = String(format: "%06d", Int.random(in: 0...999999))
        currentOTP = otp
        return otp
    }
    
    // Send OTP via email
    func sendEmailOTP(to recipientEmail: String, otp: String, completion: @escaping (Bool) -> Void) {
        let smtp = SMTP(
            hostname: "smtp.gmail.com",
            email: "polyfixit@gmail.com",
            password: "ewwa qmbj edbh qhnz", // Make sure to use a secure way to store passwords
            port: 587,
            tlsMode: .requireSTARTTLS
        )
        
        let from = Mail.User(name: "App OTP", email: "polyfixit@gmail.com")
        let to = Mail.User(email: recipientEmail)
        
        let mail = Mail(
            from: from,
            to: [to],
            subject: "Your OTP Code",
            text: "Your OTP code is: \(otp)"
        )
        
        smtp.send(mail) { error in
            if let error = error {
                print("Error sending OTP: \(error)")
                completion(false)
            } else {
                print("OTP sent successfully to \(recipientEmail)")
                completion(true)
            }
        }
    }
    
    // Function to show an alert
    func showAlert(message: String) {
        let alert = UIAlertController(title: "Signup", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    // Validate email format using regular expression
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailTest.evaluate(with: email)
    }
}
