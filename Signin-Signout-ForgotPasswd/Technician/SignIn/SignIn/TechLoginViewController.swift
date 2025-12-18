import UIKit
import FirebaseAuth
import FirebaseFirestore

// =============================
// Merged Technician Struct
// =============================
struct Technician: Codable {
    // Personal info
    let uid: String
    let email: String
    let fullName: String
    let lastLogin: TimeInterval
    
    // Technician data
    let department: [String]
    let assignedTaskCount: Int
    let createdAt: Timestamp
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
    
    @IBOutlet weak var logoutButton: UIButton!
    @IBOutlet weak var changePasswordButton: UIButton!

    // -----------------------------
    // Inactivity timer
    // -----------------------------
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
               let technician = try? JSONDecoder().decode(Technician.self, from: savedTechData) {
                
                let currentTime = Date().timeIntervalSince1970
                let timeSinceLastLogin = currentTime - technician.lastLogin
                
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
                    print("Auto-login for:", technician.fullName, technician.email)
                    statusLabel.text = "Welcome back, \(technician.fullName)!"
                    
                    // Update last login timestamp
                    let updatedTechUser = Technician(uid: technician.uid, email: technician.email, fullName: technician.fullName, lastLogin: currentTime, department: technician.department, assignedTaskCount: technician.assignedTaskCount, createdAt: technician.createdAt)
                    if let encoded = try? JSONEncoder().encode(updatedTechUser) {
                        UserDefaults.standard.set(encoded, forKey: "loggedInTech")
                    }
                    
                    goToNextScreen()
                    startLogoutTimer()
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
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        resetLogoutTimer()
    }

    private func startLogoutTimer() {
        logoutTimer?.invalidate()
        logoutTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(autoLogout), userInfo: nil, repeats: false)
    }

    private func resetLogoutTimer() {
        logoutTimer?.invalidate()
        startLogoutTimer()
    }

    @objc private func autoLogout() {
        print("Auto logout due to inactivity")
        UserDefaults.standard.removeObject(forKey: "loggedInTech")
        do {
            try Auth.auth().signOut()
        } catch {
            print("Firebase sign out error:", error.localizedDescription)
        }
        statusLabel.text = "Session expired. Please log in again."
    }

    // =============================
    // Login Button Action
    // =============================
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        clearWarnings()

        let email = emailTextField.text ?? ""
        let password = passwordTextField.text ?? ""

        var hasError = false

        if email.isEmpty {
            emailStatusLabel.text = "Email is required"
            hasError = true
        }

        if password.isEmpty {
            passwordStatusLabel.text = "Password is required"
            hasError = true
        }

        if hasError {
            removeWarningsAfterDelay()
            return
        }

        statusLabel.text = "Checking your authorization..."

        checkIfTechnician(email: email) { isTechnician in
            if !isTechnician {
                self.showAlert(message: "You are not authorized to log in as a technician.")
                self.logoutUser()  // This is the added logoutUser() function call
                return
            }

            self.statusLabel.text = "Signing in..."

            Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    print("Auth error:", error.localizedDescription)
                    self.emailStatusLabel.text = "Check Email Address"
                    self.passwordStatusLabel.text = "Check Password"
                    self.statusLabel.text = "Login failed"
                    self.removeWarningsAfterDelay()
                    return
                }

                self.statusLabel.text = "Login successful"

                guard let uid = authResult?.user.uid else {
                    print("Failed to get UID")
                    return
                }

                print("Logged in UID:", uid)
                self.fetchTechData(uid: uid)
                self.startLogoutTimer()
            }
        }
    }

    // =============================
    // Fetch Technician Data
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

            // Extract only required fields
            guard let department = data["Department"] as? [String],
                  let assignedTaskCount = data["assignedTaskCount"] as? Int,
                  let createdAt = data["createdAt"] as? Timestamp,
                  let email = data["email"] as? String,
                  let fullName = data["fullName"] as? String else {
                print("Error extracting technician data")
                return
            }

            // Create Technician object
            let technician = Technician(uid: uid, email: email, fullName: fullName, lastLogin: Date().timeIntervalSince1970, department: department, assignedTaskCount: assignedTaskCount, createdAt: createdAt)

            // Store Technician data locally
            if let encoded = try? JSONEncoder().encode(technician) {
                UserDefaults.standard.set(encoded, forKey: "loggedInTech")
            }

            self.goToNextScreen()
        }
    }

    // =============================
    // Logout Button Action
    // =============================
    @IBAction func logoutButtonTapped(_ sender: UIButton) {
        print("Logout button tapped")
        
        UserDefaults.standard.removeObject(forKey: "loggedInTech")
        
        do {
            try Auth.auth().signOut()
        } catch {
            print("Firebase sign out error:", error.localizedDescription)
        }
        statusLabel.text = "You have logged out."
    }

    // =============================
    // Helper Methods
    // =============================
    private func clearWarnings() {
        emailStatusLabel.text = ""
        passwordStatusLabel.text = ""
        statusLabel.text = ""
    }

    private func removeWarningsAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.clearWarnings()
        }
    }

    private func goToNextScreen() {
        // Navigate to the next screen, e.g., technician's dashboard or main screen
        print("Navigating to next screen")
    }

    // =============================
    // Missing Functions
    // =============================

    // Check if the email belongs to a technician
    private func checkIfTechnician(email: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        db.collection("technicians")
            .whereField("email", isEqualTo: email) // Assuming you're using the email to find technicians
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error checking if technician:", error.localizedDescription)
                    completion(false)
                    return
                }
                // If the document exists, they are a technician
                let isTechnician = snapshot?.documents.count ?? 0 > 0
                completion(isTechnician)
            }
    }

    // Show alert message
    private func showAlert(message: String) {
        let alertController = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }

    // Logout user and clear data
    private func logoutUser() {
        // Clear saved technician data from UserDefaults
        UserDefaults.standard.removeObject(forKey: "loggedInTech")
        
        // Log out from Firebase Authentication
        do {
            try Auth.auth().signOut()
            print("User logged out successfully")
        } catch {
            print("Firebase sign out error:", error.localizedDescription)
        }
        
        // Update UI or go back to login screen
        statusLabel.text = "You have been logged out."
        goToNextScreen() // or any other logic for logging out the user
    }
}
