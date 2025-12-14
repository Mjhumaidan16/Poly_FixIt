import UIKit
import FirebaseAuth
import FirebaseFirestore

// =============================
// Define the structure to store technician information locally
// =============================
// This struct will hold the technician's UID, email, name, and the last login timestamp.
// It conforms to Codable so it can be easily saved to UserDefaults in JSON format.
struct TechUser: Codable {
    let uid: String
    let email: String
    let name: String
    let lastLogin: TimeInterval
}

class TechLoginViewController: UIViewController {

    // -----------------------------
    // IBOutlets: UI elements from storyboard
    // -----------------------------
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var emailStatusLabel: UILabel!
    @IBOutlet weak var passwordStatusLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    @IBOutlet weak var logoutButton: UIButton! // ✅ Added logout button IBOutlet
    @IBOutlet weak var changePasswordButton: UIButton! // ✅ Added change password button IBOutlet

    // -----------------------------
    // Inactivity timer
    // -----------------------------
    // This timer tracks technician inactivity to auto-logout after 5 minutes.
    var logoutTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Clear any previous warning messages
        clearWarnings()

        // -----------------------------
        // AUTO-LOGIN CHECK
        // -----------------------------
        if let currentUser = Auth.auth().currentUser {
            // Firebase user exists, now check stored technician info
            if let savedTechData = UserDefaults.standard.data(forKey: "loggedInTech"),
               let techUser = try? JSONDecoder().decode(TechUser.self, from: savedTechData) {
                
                let currentTime = Date().timeIntervalSince1970
                let timeSinceLastLogin = currentTime - techUser.lastLogin
                
                // Expire after 24h (currently set to 60 sec for testing)
                if timeSinceLastLogin > 60 {
                    print("Auto logout, last login expired")
                    UserDefaults.standard.removeObject(forKey: "loggedInTech")
                    do {
                        try Auth.auth().signOut()
                    } catch {
                        print("Firebase sign out error:", error.localizedDescription)
                    }
                } else {
                    // Auto-login
                    print("Auto-login for:", techUser.name, techUser.email)
                    statusLabel.text = "Welcome back, \(techUser.name)!"
                    
                    // Update last login timestamp
                    let updatedTechUser = TechUser(uid: techUser.uid, email: techUser.email, name: techUser.name, lastLogin: currentTime)
                    if let encoded = try? JSONEncoder().encode(updatedTechUser) {
                        UserDefaults.standard.set(encoded, forKey: "loggedInTech")
                    }
                    
                    goToNextScreen()
                    startLogoutTimer() // ✅ Start timer after auto-login
                }
            } else {
                // If no UserDefaults stored, fetch from Firestore
                print("No saved technician data, fetching from Firestore")
                fetchTechData(uid: currentUser.uid)
            }
        } else {
            print("No Firebase user, please log in manually")
        }
    }

    // -----------------------------
    // User Interaction Handling
    // -----------------------------
    // Reset the inactivity timer whenever the user touches the screen
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        resetLogoutTimer()
    }

    // Start the inactivity timer
    private func startLogoutTimer() {
        logoutTimer?.invalidate() // Stop any previous timer
        // Set a timer for 5 minutes (300 seconds), 30s is the test
        logoutTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(autoLogout), userInfo: nil, repeats: false)
    }

    // Reset the inactivity timer (call this on user interaction)
    private func resetLogoutTimer() {
        logoutTimer?.invalidate()
        startLogoutTimer()
    }

    // Called when the inactivity timer expires
    @objc private func autoLogout() {
        print("Auto logout due to 5 minutes inactivity")
        UserDefaults.standard.removeObject(forKey: "loggedInTech") // Clear stored technician data
        do {
            try Auth.auth().signOut() // Sign out from Firebase
        } catch {
            print("Firebase sign out error:", error.localizedDescription)
        }
        statusLabel.text = "Session expired. Please log in again."
    }

    // =============================
    // Login Button Action
    // =============================
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        // Clear previous warnings
        clearWarnings()

        // Get input values
        let email = emailTextField.text ?? ""
        let password = passwordTextField.text ?? ""

        var hasError = false

        // Validate that the email field is not empty
        if email.isEmpty {
            emailStatusLabel.text = "Email is required"
            hasError = true
        }

        // Validate that the password field is not empty
        if password.isEmpty {
            passwordStatusLabel.text = "Password is required"
            hasError = true
        }

        // If there were any validation errors, stop and remove warnings after delay
        if hasError {
            removeWarningsAfterDelay()
            return
        }

        // Show signing in status
        statusLabel.text = "Checking your authorization..."

        // -----------------------------
        // STEP 1: Check if the user is a technician first
        // -----------------------------
        checkIfTechnician(email: email) { isTechnician in
            if !isTechnician {
                // Show alert that the user is not authorized
                self.showAlert(message: "You are not authorized to log in as a technician.")

                // Logout the user immediately (if they were signed in previously)
                self.logoutUser()

                return // Don't continue with Firebase login process
            }

            // -----------------------------
            // STEP 2: If the user is a technician, proceed with Firebase authentication
            // -----------------------------
            self.statusLabel.text = "Signing in..."

            Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    // Handle authentication errors
                    print("Auth error:", error.localizedDescription)

                    self.emailStatusLabel.text = "Check Email Address"
                    self.passwordStatusLabel.text = "Check Password"
                    self.statusLabel.text = "Login failed"

                    self.removeWarningsAfterDelay()
                    return
                }

                // ✅ Login successful
                self.statusLabel.text = "Login successful"

                guard let uid = authResult?.user.uid else {
                    print("Failed to get UID")
                    return
                }

                print("Logged in UID:", uid)

                // Fetch technician data from Firestore
                self.fetchTechData(uid: uid)
                self.startLogoutTimer() // ✅ Start timer after manual login
            }
        }
    }

    // =============================
    // Firestore: Fetch Technician Data
    // =============================
    private func fetchTechData(uid: String) {
        let db = Firestore.firestore()
        db.collection("technicians").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("Firestore fetch error:", error.localizedDescription)
                return
            }

            guard let data = snapshot?.data() else {
                print("No technician document found for UID:", uid)
                return
            }

            // Extract technician fields
            let email = data["email"] as? String ?? "N/A"
            let fullName = data["fullName"] as? String ?? "N/A" // Changed to fullName

            // Print fetched technician data for debugging
            print("✅ TECHNICIAN DATA FETCHED")
            print("Full Name:", fullName)
            print("Email:", email)

            // -----------------------------
            // Store Technician Data Locally
            // -----------------------------
            // Save UID, email, fullName, and last login timestamp to UserDefaults
            let currentTime = Date().timeIntervalSince1970
            let techUser = TechUser(uid: uid, email: email, name: fullName, lastLogin: currentTime)

            if let encoded = try? JSONEncoder().encode(techUser) {
                UserDefaults.standard.set(encoded, forKey: "loggedInTech")
            }

            // Navigate to the next screen in the app
            self.goToNextScreen()
        }
    }

    // =============================
    // Logout Button Action
    // =============================
    @IBAction func logoutButtonTapped(_ sender: UIButton) {
        print("Logout button tapped")
        
        // Remove saved technician data
        UserDefaults.standard.removeObject(forKey: "loggedInTech")
        
        // Sign out from Firebase
        do {
            try Auth.auth().signOut()
        } catch {
            print("Firebase sign out error:", error.localizedDescription)
        }
        
        // Update UI
        statusLabel.text = "Logged out. Please log in again."
        
        // Invalidate inactivity timer
        logoutTimer?.invalidate()
    }

    // =============================
    // Helper Methods
    // =============================
    private func clearWarnings() {
        // Clear warning labels
        emailStatusLabel.text = ""
        passwordStatusLabel.text = ""
    }

    private func removeWarningsAfterDelay() {
        // Remove warnings after 7 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
            self.clearWarnings()
        }
    }

    private func goToNextScreen() {
        // Placeholder method to navigate to the next screen
        print("Navigate to next screen")
    }

    // =====================
    // Helper Method to Check Technician Status
    // =====================
    private func checkIfTechnician(email: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        db.collection("technicians").whereField("email", isEqualTo: email).getDocuments { (snapshot, error) in
            if let error = error {
                print("Firestore error:", error.localizedDescription)
                completion(false)
                return
            }

            // Check if any documents exist for the technician email
            if let snapshot = snapshot, snapshot.documents.isEmpty {
                // If no technician found with this email, return false
                completion(false)
            } else {
                // Technician found
                completion(true)
            }
        }
    }

    // =====================
    // Logout User (if they are not authorized)
    // =====================
    private func logoutUser() {
        // Remove saved technician data
        UserDefaults.standard.removeObject(forKey: "loggedInTech")
        
        // Sign out from Firebase
        do {
            try Auth.auth().signOut()
            print("User signed out because they are not a technician")
        } catch {
            print("Firebase sign out error:", error.localizedDescription)
        }
        
        // Update UI
        statusLabel.text = "Session expired. Please log in again."
        
        // Invalidate inactivity timer (if any)
        logoutTimer?.invalidate()
    }

    // =====================
    // Show Alert
    // =====================
    private func showAlert(message: String) {
        let alertController = UIAlertController(title: "Login Error", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
}
