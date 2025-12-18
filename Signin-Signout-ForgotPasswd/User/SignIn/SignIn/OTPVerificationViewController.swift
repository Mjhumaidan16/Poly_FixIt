import UIKit
import FirebaseAuth
import FirebaseFirestore

class OTPVerificationViewController: UIViewController {
    
    @IBOutlet weak var otpTextField: UITextField!
    @IBOutlet weak var statusLabel: UILabel!
    
    var email: String? // Store email passed from previous view controller
    var otp: String?   // Store OTP passed from previous view controller
    var userData: [String: String]? // Store user data passed from the first screen

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func verifyOTPButtonTapped(_ sender: UIButton) {
        guard let otpInput = otpTextField.text, !otpInput.isEmpty else {
            statusLabel.text = "Enter OTP"
            return
        }
        
        // Check if the input OTP matches the OTP sent earlier
        if otpInput == otp {
            statusLabel.text = "OTP verified"
            
            // Now create the Firebase Auth user and Firestore document
            createFirebaseUser()
        } else {
            statusLabel.text = "Incorrect OTP. Please try again."
        }
    }
    
    // Create the Firebase user and save data to Firestore
    func createFirebaseUser() {
        guard let email = email, let password = userData?["password"] else {
            statusLabel.text = "Missing user information."
            print("Missing email or password.")
            return
        }
        
        // Create Firebase user
        Auth.auth().createUser(withEmail: email, password: password) { (authResult, error) in
            if let error = error {
                self.statusLabel.text = "\(error.localizedDescription)"
                print("Error creating user: \(error.localizedDescription)")
                return
            }
            
            // User successfully created, now store additional user data in Firestore
            self.storeUserDataInFirestore(user: authResult!.user)
        }
    }
    
    // Store the user data in Firestore
    func storeUserDataInFirestore(user: FirebaseAuth.User) {
        let db = Firestore.firestore()
        let userDoc = db.collection("users").document(user.uid)
        
        // Clean phone number if necessary (just in case there are non-numeric characters)
        let phoneNumber = self.userData?["phone"]?.filter { "0123456789".contains($0) } ?? ""
        
        let userData: [String: Any] = [
            "createdAt": Timestamp(),
            "email": user.email ?? "",
            "fullName": self.userData?["name"] ?? "",
            "isActive": true,
            "phoneNumber": phoneNumber,  // Store phone number as a string
            "requestHistory": [],
            "role": "student"
        ]
        
        userDoc.setData(userData) { error in
            if let error = error {
                self.statusLabel.text = "Failed to save user data: \(error.localizedDescription)"
                print("Error storing data in Firestore: \(error.localizedDescription)")
            } else {
                self.statusLabel.text = "User created successfully."
                print("User data successfully saved to Firestore.")
                
                // Navigate to the main SignIn page (UserLoginViewController)
                self.navigateToSignIn()
            }
        }
    }

    // Navigate to SignIn (UserLoginViewController)
    func navigateToSignIn() {
        // If you're using a navigation controller, use popToRootViewController:
        if let navController = self.navigationController {
            navController.popToRootViewController(animated: true)
        } else {
            // Alternatively, if not using a navigation controller, present the SignIn screen directly
            if let signInVC = self.storyboard?.instantiateViewController(withIdentifier: "UserChangePasswordViewController") {
                self.present(signInVC, animated: true, completion: nil)
            }
        }
    }
}
