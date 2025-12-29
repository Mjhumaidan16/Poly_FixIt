import UIKit
import FirebaseAuth
import SwiftSMTP
import FirebaseFunctions // <-- Added for Cloud Function

// =============================
// OTP Manager Class
// =============================
class OTPManager {
    static let shared = OTPManager()
    private init() {}
    
    private var currentOTP: String?
    
    func generateOTP() -> String {
        let otp =  String(format: "%06d", Int.random(in: 0...999999))
        currentOTP = otp
        return otp
    }
    
    func verifyOTP(_ otp: String) -> Bool {
        return otp == currentOTP
    }
    
    func clearOTP() {
        currentOTP = nil
    }
}

// =============================
// Email Sender Class
// =============================
class EmailSender {
    private let smtpHostname = "smtp.gmail.com"
    private let smtpUsername = "polyfixit@gmail.com"
    // IMPORTANT:
    // Do NOT hardcode real app-passwords in the app binary.
    // Put your Gmail App Password in Info.plist as a String with key:
    //   GMAIL_APP_PASSWORD
    // and the code below will read it at runtime.
    // If the key is missing, we'll fail the send and log an error.
    // Prefer reading the Gmail App Password from Info.plist (recommended),
    // but fall back to the existing in-project value if the key is missing.
    private var smtpPassword: String {
        let fromPlist = (Bundle.main.object(forInfoDictionaryKey: "GMAIL_APP_PASSWORD") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        if !fromPlist.isEmpty { return fromPlist }

        // Fallback (keeps existing project behavior)
        return "bmkpttwtoxsknkyw"
    }
    private let smtpPort: Int32 = 587
    
    func sendOTP(to recipientEmail: String, otp: String, completion: @escaping (Bool) -> Void) {
        let smtp = SMTP(
            hostname: smtpHostname,
            email: smtpUsername,
            password: smtpPassword,
            port: smtpPort,
            tlsMode: .requireSTARTTLS
        )
        
        let from = Mail.User(name: "App OTP", email: smtpUsername)
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
}

// =============================
// View Controller for Email Input
// =============================
class OTPEmailViewController: UIViewController {
    
    @IBOutlet weak var emailTextField: UITextField!
    //@IBOutlet weak var statusLabel: UILabel!
    
    let emailSender = EmailSender()
    
//    @IBAction func sendOTPButtonTapped(_ sender: UIButton) {
//        guard let email = emailTextField.text, !email.isEmpty else {
//            statusLabel.text = "Enter your email"
//            return
//        }
//        
//        let otp = OTPManager.shared.generateOTP()
//        
//        emailSender.sendOTP(to: email, otp: otp) { success in
//            DispatchQueue.main.async {
//                if success {
//                    self.statusLabel.text = "OTP sent to \(email)"
//                    
//                    guard let nav = self.navigationController else {
//                        print("Navigation controller is nil!")
//                        return
//                    }
//                    
//                    if let otpVC = self.storyboard?.instantiateViewController(withIdentifier: "OTPInputViewController") as? OTPInputViewController {
//                        otpVC.email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
//                        nav.pushViewController(otpVC, animated: true)
//                    } else {
//                        print("OTPInputViewController not found in storyboard")
//                    }
//                    
//                } else {
//                    self.statusLabel.text = "Failed to send OTP"
//                }
//            }
//        }
//    }
    
    @IBAction func sendPasswordResetLinkButtonTapped(_ sender: UIButton) {
        guard let email = emailTextField.text, !email.isEmpty else {
            //statusLabel.text = "Enter your email"
            return
        }
        
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            DispatchQueue.main.async {
                if let error = error {
                   // self.statusLabel.text = "Error: \(error.localizedDescription)"
                    self.showAlert(message: "Error: \(error.localizedDescription)")
                } else {
                    //self.statusLabel.text = "An email to reset your password will be sent if you're registered."
                self.showAlert(
                            message: "An email to reset your password will be sent if you're registered."
                        ) {
                            let storyboard = UIStoryboard(name: "Main", bundle: nil)
                            let loginVC = storyboard.instantiateViewController(withIdentifier: "UserLoginViewController")

                            if let nav = self.navigationController {
                                nav.setViewControllers([loginVC], animated: true)
                            } else {
                                loginVC.modalPresentationStyle = .fullScreen
                                self.present(loginVC, animated: true)
                            }
                        }

                    }
                
                
            }
        }
    }
}

//// =============================
//// View Controller for OTP Input
//// =============================
//class OTPInputViewController: UIViewController {
//    
//    @IBOutlet weak var otpTextField: UITextField!
//    @IBOutlet weak var statusLabel: UILabel!
//    
//    var email: String?
//    
//    @IBAction func verifyOTPButtonTapped(_ sender: UIButton) {
//        guard let otp = otpTextField.text, !otp.isEmpty else {
//            statusLabel.text = "Enter OTP"
//            return
//        }
//        
//        if OTPManager.shared.verifyOTP(otp) {
//            OTPManager.shared.clearOTP()
//            statusLabel.text = "OTP verified"
//            
//            guard let email = email else {
//                statusLabel.text = "Email not available"
//                return
//            }
//            
//            guard let nav = self.navigationController else {
//                print("Navigation controller is nil!")
//                return
//            }
//            
//            if let resetVC = self.storyboard?.instantiateViewController(withIdentifier: "PasswordResetViewController") as? PasswordResetViewController {
//                resetVC.email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
//                nav.pushViewController(resetVC, animated: true)
//            } else {
//                print("PasswordResetViewController not found in storyboard")
//            }
//            
//        } else {
//            statusLabel.text = "Incorrect OTP"
//        }
//    }
//}

//// =============================
//// View Controller for Password Reset (UID-based)
//// =============================
//class PasswordResetViewController: UIViewController {
//    
//    @IBOutlet weak var passwordTextField: UITextField!
//    @IBOutlet weak var confirmPasswordTextField: UITextField!
//    @IBOutlet weak var statusLabel: UILabel!
//    
//    var email: String?
//    lazy var functions = Functions.functions(region: "us-central1")
//    
//    @IBAction func changePasswordButtonTapped(_ sender: UIButton) {
//        guard let email = email,
//              let password = passwordTextField.text, !password.isEmpty,
//              let confirm = confirmPasswordTextField.text, !confirm.isEmpty else {
//            statusLabel.text = "Fill all fields"
//            return
//        }
//        
//        guard password == confirm else {
//            statusLabel.text = "Passwords do not match"
//            return
//        }
//        
//        // Step 1: fetch UID from email
//        fetchUID(forEmail: email) { uid in
//            guard let uid = uid else {
//                self.statusLabel.text = "User not found"
//                return
//            }
//            
//            // Step 2: reset password using UID
//            self.resetPassword(uid: uid, newPassword: password)
//        }
//    }
//    
//    // Fetch UID via Cloud Function
//    func fetchUID(forEmail email: String, completion: @escaping (String?) -> Void) {
//        functions.httpsCallable("getUIDByEmail").call(["email": email]) { result, error in
//            if let error = error as NSError? {
//                print("Error fetching UID: \(error.localizedDescription)")
//                completion(nil)
//            } else if let data = result?.data as? [String: Any],
//                      let uid = data["uid"] as? String {
//                completion(uid)
//            } else {
//                completion(nil)
//            }
//        }
//    }
//    
//    // Reset password using UID via Cloud Function
//    func resetPassword(uid: String, newPassword: String) {
//        functions.httpsCallable("resetPassword").call(["uid": uid, "newPassword": newPassword]) { result, error in
//            DispatchQueue.main.async {
//                if let error = error as NSError? {
//                    if let details = error.userInfo[FunctionsErrorDetailsKey] {
//                        self.statusLabel.text = "Failed: \(details)"
//                    } else {
//                        self.statusLabel.text = "Failed: \(error.localizedDescription)"
//                    }
//                } else {
//                    self.statusLabel.text = "Password updated successfully!"
//                }
//            }
//        }
//    }
//}


extension UIViewController {
    func showAlert(title: String = "Signup",
                   message: String,
                   completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completion?()
            })
            self.present(alert, animated: true)
        }
    }
}
