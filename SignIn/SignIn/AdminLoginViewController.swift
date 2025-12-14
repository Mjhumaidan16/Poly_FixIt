import UIKit
import FirebaseAuth
import FirebaseFirestore

// =============================
// Define the structure to store admin information locally
// =============================
// This struct will hold the admin's UID, email, name, and the last login timestamp.
// It conforms to Codable so it can be easily saved to UserDefaults in JSON format.
struct AdminUser: Codable {
    let uid: String
    let email: String
    let name: String
    let lastLogin: TimeInterval
}

class AdminLoginViewController: UIViewController {

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
    // This timer tracks admin inactivity to auto-logout after 5 minutes.
    var logoutTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Clear any previous warning messages
        clearWarnings()

        // -----------------------------
        // AUTO-LOGIN CHECK
        // -----------------------------
        if let currentUser = Auth.auth().currentUser {
            // Firebase user exists, now check stored admin info
            if let savedAdminData = UserDefaults.standard.data(forKey: "loggedInAdmin"),
               let adminUser = try? JSONDecoder().decode(AdminUser.self, from: savedAdminData) {
                
                let currentTime = Date().timeIntervalSince1970
                let timeSinceLastLogin = currentTime - adminUser.lastLogin
                
                // Expire after 24h (currently set to 60 sec for testing)
                if timeSinceLastLogin > 60 {
                    print("Auto logout, last login expired")
                    UserDefaults.standard.removeObject(forKey: "loggedInAdmin")
                    do {
                        try Auth.auth().signOut()
                    } catch {
                        print("Firebase sign out error:", error.localizedDescription)
                    }
                } else {
                    // Auto-login
                    print("Auto-login for:", adminUser.name, adminUser.email)
                    statusLabel.text = "Welcome back, \(adminUser.name)!"
                    
                    // Update last login timestamp
                    let updatedAdminUser = AdminUser(uid: adminUser.uid, email: adminUser.email, name: adminUser.name, lastLogin: currentTime)
                    if let encoded = try? JSONEncoder().encode(updatedAdminUser) {
                        UserDefaults.standard.set(encoded, forKey: "loggedInAdmin")
                    }
                    
                    goToNextScreen()
                    startLogoutTimer() // ✅ Start timer after auto-login
                }
            } else {
                // If no UserDefaults stored, fetch from Firestore
                print("No saved admin data, fetching from Firestore")
                fetchAdminData(uid: currentUser.uid)
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
        UserDefaults.standard.removeObject(forKey: "loggedInAdmin") // Clear stored admin data
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
        statusLabel.text = "Signing in..."

        // -----------------------------
        // SIGN IN USING FIREBASE AUTH
        // -----------------------------
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

            // Fetch admin data from Firestore
            self.fetchAdminData(uid: uid)
            self.startLogoutTimer() // ✅ Start timer after manual login
        }
    }

    // =============================
    // Firestore: Fetch Admin Data
    // =============================
    private func fetchAdminData(uid: String) {
        let db = Firestore.firestore()
        db.collection("admin").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("Firestore fetch error:", error.localizedDescription)
                return
            }

            guard let data = snapshot?.data() else {
                print("No admin document found for UID:", uid)
                return
            }

            // Extract admin fields
            let email = data["email"] as? String ?? "N/A"
            let name = data["name"] as? String ?? "N/A"

            // Print fetched admin data for debugging
            print("✅ ADMIN DATA FETCHED")
            print("Name:", name)
            print("Email:", email)

            // -----------------------------
            // Store Admin Data Locally
            // -----------------------------
            // Save UID, email, name, and last login timestamp to UserDefaults
            let currentTime = Date().timeIntervalSince1970
            let adminUser = AdminUser(uid: uid, email: email, name: name, lastLogin: currentTime)

            if let encoded = try? JSONEncoder().encode(adminUser) {
                UserDefaults.standard.set(encoded, forKey: "loggedInAdmin")
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
        
        // Remove saved admin data
        UserDefaults.standard.removeObject(forKey: "loggedInAdmin")
        
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
}
