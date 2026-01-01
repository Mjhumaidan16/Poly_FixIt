import UIKit
import FirebaseAuth
import FirebaseFirestore

// =============================
// Merged Admin Struct
// =============================
struct Admin: Codable {
    // Personal info
    let uid: String
    let email: String
    let fullName: String
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
    //@IBOutlet weak var statusLabel: UILabel!
    
    //@IBOutlet weak var changePasswordButton: UIButton!

    // Inactivity timeout is handled globally by SessionManager.

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Stop inactivity monitoring ONLY when the user is actually logged out.
        // Otherwise, coming back to this screen (or an auto-login navigation) can
        // unintentionally kill the session timer.
        if Auth.auth().currentUser == nil {
            SessionManager.shared.stop()
        }
    }

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
               let admin = try? JSONDecoder().decode(Admin.self, from: savedAdminData) {
                
                let currentTime = Date().timeIntervalSince1970

                // Auto-login
                print("Auto-login for:", admin.fullName, admin.email)
                //statusLabel.text = "Welcome back, \(admin.fullName)!"

                // Update last login timestamp
                let updatedAdminUser = Admin(
                    uid: admin.uid,
                    email: admin.email,
                    fullName: admin.fullName,
                    lastLogin: currentTime
                )
                if let encoded = try? JSONEncoder().encode(updatedAdminUser) {
                    UserDefaults.standard.set(encoded, forKey: "loggedInAdmin")
                }

                SessionManager.shared.start()
                SessionManager.shared.userDidInteract()
                goToNextScreen()
            } else {
                // If no UserDefaults stored, fetch from Firestore
                print("No saved admin data, fetching from Firestore")
                fetchAdminData(uid: currentUser.uid)
            }
        } else {
            print("No Firebase user, please log in manually")
        }
    }

    // NOTE: Touch handling / inactivity timeout is global via AdminApplication + SessionManager.

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


        checkIfAdmin(email: email) { isAdmin in
            if !isAdmin {
                self.showAlert(message: "You are not authorized to log in as an admin!")
                self.logoutUser()
                return
                
            }


            Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    print("Auth error:", error.localizedDescription)
                    self.emailStatusLabel.text = "Check Email Address"
                    self.passwordStatusLabel.text = "Check Password"
                    //self.statusLabel.text = "Login failed"
                    self.removeWarningsAfterDelay()
                    return
                }

                //self.statusLabel.text = "Login successful"

                guard let uid = authResult?.user.uid else {
                    print("Failed to get UID")
                    return
                }

                print("Logged in UID:", uid)
                self.fetchAdminData(uid: uid)
                SessionManager.shared.userDidInteract()
                
            }
        }
    }

    // =============================
    // Fetch Admin Data
    // =============================
    private func fetchAdminData(uid: String) {
        let db = Firestore.firestore()
        db.collection("admin").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("Firestore fetch error:", error.localizedDescription)
                return
            }

            guard let data = snapshot?.data(),
                  let email = data["email"] as? String,
                  let fullName = data["name"] as? String else {
                print("No admin document found for UID:", uid)
                return
            }

            let admin = Admin(
                uid: uid,
                email: email,
                fullName: fullName,
                lastLogin: Date().timeIntervalSince1970
            )

            if let encoded = try? JSONEncoder().encode(admin) {
                UserDefaults.standard.set(encoded, forKey: "loggedInAdmin")
            }

            SessionManager.shared.start()
            SessionManager.shared.userDidInteract()
            self.goToNextScreen()
        }
    }

//    // =============================
//    // Logout Button Action
//    // =============================
//    @IBAction func logoutButtonTapped(_ sender: UIButton) {
//        print("Logout button tapped")
//        
//        UserDefaults.standard.removeObject(forKey: "loggedInAdmin")
//        
//        do {
//            try Auth.auth().signOut()
//        } catch {
//            print("Firebase sign out error:", error.localizedDescription)
//        }
//    }

    // =============================
    // Helper Methods
    // =============================
    private func clearWarnings() {
        emailStatusLabel.text = ""
        passwordStatusLabel.text = ""
        //statusLabel.text = ""
    }

    private func removeWarningsAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.clearWarnings()
        }
    }

    private func goToNextScreen() {
        print("Navigating to next screen")

        let main = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "AdminTabBarViewController")

        // Replace root safely (SceneDelegate)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let delegate = scene.delegate as? SceneDelegate,
           let window = delegate.window {
            window.rootViewController = main
            window.makeKeyAndVisible()
        } else {
            // fallback
            self.navigationController?.setViewControllers([main], animated: true)
        }
    }

    // =============================
    // Missing Functions
    // =============================

    // Check if the email belongs to an admin
    private func checkIfAdmin(email: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        db.collection("admin")
            .whereField("email", isEqualTo: email)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error checking if admin:", error.localizedDescription)
                    completion(false)
                    return
                }
                let isAdmin = snapshot?.documents.count ?? 0 > 0
                completion(isAdmin)
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
        // Clear saved admin data from UserDefaults
        UserDefaults.standard.removeObject(forKey: "loggedInAdmin")
        
        // Log out from Firebase Authentication
        do {
            try Auth.auth().signOut()
            print("User logged out successfully")
        } catch {
            print("Firebase sign out error:", error.localizedDescription)
        }
    }
}
