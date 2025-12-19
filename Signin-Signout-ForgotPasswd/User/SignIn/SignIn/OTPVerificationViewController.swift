import UIKit
import FirebaseAuth
import FirebaseFirestore

class OTPVerificationViewController: UIViewController {

    // MARK: - Properties
    var name: String?
    var phone: String?
    var email: String?
    var password: String?
    
    // Variable to store the generated OTP
    var generatedOTP: String?
    
    // MARK: - UI Elements
    @IBOutlet weak var otpLabel: UILabel!
    @IBOutlet weak var otpTextField: UITextField!
    @IBOutlet weak var verifyButton: UIButton!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup the label with a welcome message and the phone number
        otpLabel.text = "Enter OTP sent to your email address \(email ?? "")"
        
        // Generate OTP and send it to the email
        generateAndSendOTP()
        
        // Additional setup (e.g., styling)
        styleUI()
    }
    
    // MARK: - UI Setup
    func styleUI() {
        // Optionally style the label, text field, and button
        otpTextField.placeholder = "Enter OTP"
        otpTextField.borderStyle = .roundedRect
        otpTextField.keyboardType = .numberPad
        
        verifyButton.layer.cornerRadius = 10
        verifyButton.backgroundColor = .systemBlue
        verifyButton.setTitleColor(.white, for: .normal)
    }
    
    // MARK: - OTP Generation and Email Sending
    func generateAndSendOTP() {
        // Generate a random 6-digit OTP
        let otp = String(format: "%06d", Int.random(in: 0...999999))
        generatedOTP = otp
        
        // Use EmailSender class to send OTP to the provided email
        let emailSender = EmailSender()
        emailSender.sendOTP(to: email ?? "", otp: otp) { success in
            if success {
                print("OTP sent successfully to \(self.email ?? "")")
            } else {
                self.showAlert(message: "Failed to send OTP to email.")
            }
        }
    }
    
    // MARK: - Actions
    @IBAction func verifyButtonTapped(_ sender: UIButton) {
        // Get the OTP entered by the user
        guard let otp = otpTextField.text, !otp.isEmpty else {
            showAlert(message: "Please enter the OTP.")
            return
        }
        
        // Check if the OTP entered by the user matches the generated OTP
        if otp == generatedOTP {
            // Show success message
            showAlert(message: "OTP Verified Successfully!")
            
            // Proceed with creating the user in Firebase Auth and Firestore
            createUserInAuthAndFirestore()
        } else {
            showAlert(message: "Invalid OTP. Please try again.")
        }
    }
    
    // MARK: - Create User in Firebase Auth and Firestore
    func createUserInAuthAndFirestore() {
        guard let email = email, let password = password else {
            showAlert(message: "Missing email or password.")
            return
        }

        // Create the user in Firebase Auth
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            if let error = error {
                self?.showAlert(message: "Error creating user: \(error.localizedDescription)")
                return
            }
            
            guard let user = authResult?.user else { return }
            
            // Now that the user is created, create the Firestore document with the user's UID
            self?.createUserDocument(uid: user.uid)
        }
    }
    
    // MARK: - Create Firestore User Document
    func createUserDocument(uid: String) {
        guard let name = name, let phone = phone, let email = email else {
            showAlert(message: "Missing user data.")
            return
        }

        // Convert the phone number to an integer if possible
        guard let phoneNumber = Int(phone) else {
            showAlert(message: "Invalid phone number.")
            return
        }
        
        // Firestore reference
        let db = Firestore.firestore()
        
        // Create the user document with the UID
        let userDocument = db.collection("users").document(uid)
        
        userDocument.setData([
            "createdAt": Timestamp(),
            "email": email,
            "fullName": name,
            "isActive": true,
            "phoneNumber": phoneNumber,
            "requestHistory": [],
            "role": "student"
        ]) { error in
            if let error = error {
                self.showAlert(message: "Error saving user data: \(error.localizedDescription)")
            } else {
                self.showAlert(message: "User created successfully!")
            }
        }
    }
    
    // MARK: - Helper Functions
    func showAlert(message: String) {
        let alert = UIAlertController(title: "OTP Verification", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
