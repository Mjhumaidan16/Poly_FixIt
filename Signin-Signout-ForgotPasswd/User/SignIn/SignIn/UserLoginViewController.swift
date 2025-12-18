import UIKit
import FirebaseAuth
import FirebaseFirestore

// =============================
// User Struct to store logged in user info
// =============================
struct AppUser: Codable {
    let uid: String
    let email: String
    let fullName: String
    let lastLogin: TimeInterval
}

class UserLoginViewController: UIViewController {

    // =============================
    // MARK: - IBOutlets: Storyboard UI elements
    // =============================
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var emailStatusLabel: UILabel!
    @IBOutlet weak var passwordStatusLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    @IBOutlet weak var logoutButton: UIButton!
    @IBOutlet weak var changePasswordButton: UIButton!

    // Timer for auto-logout due to inactivity
    var logoutTimer: Timer?

    // =============================
    // MARK: - View Lifecycle
    // =============================
    override func viewDidLoad() {
        super.viewDidLoad()
        clearWarnings() // remove any leftover messages

        // Check if Firebase already has a logged-in user
        if let currentUser = Auth.auth().currentUser {
            
            // Try to restore user from UserDefaults
            if let savedUserData = UserDefaults.standard.data(forKey: "loggedInUser"),
               let user = try? JSONDecoder().decode(AppUser.self, from: savedUserData) {

                let currentTime = Date().timeIntervalSince1970
                let timeSinceLastLogin = currentTime - user.lastLogin

                // If more than 60 seconds (testing), force logout
                if timeSinceLastLogin > 60 {
                    UserDefaults.standard.removeObject(forKey: "loggedInUser")
                    do { try Auth.auth().signOut() } catch {}
                } else {
                    // Quick auto-login
                    statusLabel.text = "Welcome back, \(user.fullName)!"
                    let updatedUser = AppUser(uid: user.uid, email: user.email, fullName: user.fullName, lastLogin: currentTime)
                    if let encoded = try? JSONEncoder().encode(updatedUser) {
                        UserDefaults.standard.set(encoded, forKey: "loggedInUser")
                    }
                    goToNextScreen()
                    startLogoutTimer()
                }
            } else {
                // No saved data? Fetch from Firestore directly
                fetchUserData(uid: currentUser.uid)
            }
        }
    }

    // Dismiss keyboard if user taps outside
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        resetLogoutTimer()
    }

    // =============================
    // MARK: - Auto Logout Timer
    // =============================
    private func startLogoutTimer() {
        logoutTimer?.invalidate()
        logoutTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(autoLogout), userInfo: nil, repeats: false)
    }

    private func resetLogoutTimer() {
        logoutTimer?.invalidate()
        startLogoutTimer()
    }

    @objc private func autoLogout() {
        // Auto logout if user is inactive
        UserDefaults.standard.removeObject(forKey: "loggedInUser")
        do { try Auth.auth().signOut() } catch {}
        statusLabel.text = "Session expired. Please log in again."
    }

    // =============================
    // MARK: - Login Button Action
    // =============================
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        clearWarnings()

        let email = emailTextField.text ?? ""
        let password = passwordTextField.text ?? ""

        var hasError = false
        if email.isEmpty { emailStatusLabel.text = "Email is required"; hasError = true }
        if password.isEmpty { passwordStatusLabel.text = "Password is required"; hasError = true }
        if hasError { removeWarningsAfterDelay(); return }

        statusLabel.text = "Checking your authorization..."

        // First, check if this email exists in the users collection
        checkIfUserExists(email: email) { isUser in
            if !isUser {
                self.showAlert(message: "You are not authorized to log in as a user.")
                self.logoutUser()
                return
            }

            self.statusLabel.text = "Signing in..."
            
            // Proceed to Firebase authentication
            Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    print("Auth error:", error.localizedDescription)
                    self.emailStatusLabel.text = "Check Email Address"
                    self.passwordStatusLabel.text = "Check Password"
                    self.statusLabel.text = "Login failed"
                    self.removeWarningsAfterDelay()
                    return
                }

                // Fetch full user data from Firestore after successful sign in
                guard let uid = authResult?.user.uid else { return }
                self.fetchUserData(uid: uid)
                self.startLogoutTimer()
            }
        }
    }

    // =============================
    // Fetch User Info from Firestore
    // =============================
    private func fetchUserData(uid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Firestore fetch error:", error.localizedDescription)
                    self.statusLabel.text = "Failed to fetch user data"
                    return
                }

                guard let data = snapshot?.data() else {
                    print("No user document found for UID:", uid)
                    self.statusLabel.text = "User data not found"
                    return
                }

                let email = data["email"] as? String ?? "Unknown"
                let fullName = data["fullName"] as? String ?? "User"

                let user = AppUser(uid: uid, email: email, fullName: fullName, lastLogin: Date().timeIntervalSince1970)

                // Save logged in user locally for auto-login next time
                if let encoded = try? JSONEncoder().encode(user) {
                    UserDefaults.standard.set(encoded, forKey: "loggedInUser")
                }

                // Friendly message to the user
                self.statusLabel.text = "Logged in as \(fullName)"
                self.goToNextScreen()
            }
        }
    }

    // =============================
    // Logout Button Action
    // =============================
    @IBAction func logoutButtonTapped(_ sender: UIButton) {
        UserDefaults.standard.removeObject(forKey: "loggedInUser")
        do { try Auth.auth().signOut() } catch {}
        statusLabel.text = "You have logged out."
    }

    // =============================
    // MARK: - Helpers
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
        // Navigate to the user's main screen or dashboard
        print("Navigating to next screen")
    }

    // Check if the email exists in Firestore users collection
    private func checkIfUserExists(email: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments { snapshot, error in
                if let error = error { print(error.localizedDescription); completion(false); return }
                let isUser = snapshot?.documents.count ?? 0 > 0
                completion(isUser)
            }
    }

    // Show a friendly alert
    private func showAlert(message: String) {
        let alertController = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }

    // Logout the user safely
    private func logoutUser() {
        UserDefaults.standard.removeObject(forKey: "loggedInUser")
        do { try Auth.auth().signOut() } catch {}
        statusLabel.text = "You have been logged out."
        goToNextScreen()
    }
}
