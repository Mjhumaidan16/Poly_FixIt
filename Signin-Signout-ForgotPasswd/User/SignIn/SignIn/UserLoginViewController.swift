import UIKit
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import Firebase

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
    @IBOutlet weak var googleSignInButton: UIButton! // Added IBOutlet for Google Sign-In Button

    // =============================
    // MARK: - View Lifecycle
    // =============================
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Stop inactivity monitoring ONLY when the user is actually logged out.
        // Otherwise, auto-login or returning to this screen can unintentionally kill the session timer.
        if Auth.auth().currentUser == nil {
            SessionManager.shared.stop()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        clearWarnings() // remove any leftover messages

        // Check if Firebase already has a logged-in user
        if let currentUser = Auth.auth().currentUser {
            
            // Try to restore user from UserDefaults
            if let savedUserData = UserDefaults.standard.data(forKey: "loggedInUser"),
               let user = try? JSONDecoder().decode(AppUser.self, from: savedUserData) {

                let currentTime = Date().timeIntervalSince1970

                // Quick auto-login
                statusLabel.text = "Welcome back, \(user.fullName)!"
                let updatedUser = AppUser(uid: user.uid, email: user.email, fullName: user.fullName, lastLogin: currentTime)
                if let encoded = try? JSONEncoder().encode(updatedUser) {
                    UserDefaults.standard.set(encoded, forKey: "loggedInUser")
                }
                SessionManager.shared.start()
                SessionManager.shared.userDidInteract()
                goToNextScreen()
            } else {
                // No saved data? Fetch from Firestore directly
                fetchUserData(uid: currentUser.uid)
            }
        }
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
                self.showAlert(message: "You are not authorized or registered to log in as a user.")
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
                    //self.statusLabel.text = "User data not found"
                    self.showAlert(message: "You need to sign up first.")
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
                SessionManager.shared.start()
                SessionManager.shared.userDidInteract()
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
    // MARK: - Google Sign-In Button Action
    // =============================
    @IBAction func googleSignInTapped(_ sender: UIButton) {
        // Ensure Firebase is configured with the correct clientID
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Initiate Google Sign-In process
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { result, error in
            // Handle Google Sign-In errors
            if let error = error {
                print("Google Sign-In Error: \(error.localizedDescription)")
                return
            }

            // Get the ID Token and Access Token from the Google account
            guard let user = result?.user, let idToken = user.idToken?.tokenString else {
                print("Failed to get Google user or ID token.")
                return
            }

            // Create a Firebase credential with the Google sign-in tokens
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)

            // Sign in with Firebase using the Google credentials
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Firebase Sign-In Error: \(error.localizedDescription)")
                    return
                }

                // Now, we can safely unwrap the `user` object from the `authResult`
                guard let firebaseUser = authResult?.user else {
                    print("Failed to get Firebase user.")
                    return
                }

                // Check if the user has a document in Firestore linked to their UID
                self.checkUserDocument(uid: firebaseUser.uid, user: firebaseUser)
            }
        }
    }

    // Function to check if the user has a document in Firestore
    func checkUserDocument(uid: String, user: User) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)

        // Fetch the user document from Firestore
        userRef.getDocument { document, error in
            if let error = error {
                print("Error fetching user document: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists {
                // User document exists, meaning the user is signed in
                print("User document found. User is signed in.")
                self.fetchUserData(uid: uid) // Use the pre-declared fetchUserData function
            } else {
                // User document does not exist, meaning the user is signing up
                print("User document not found. User is signing up.")
                self.handleNewUserSignUp(uid: uid, user: user) // Handle the new user sign-up process
            }
        }
    }

    func handleNewUserSignUp(uid: String, user: User) {
        // Collect the user's information from the Google profile
        let userEmail = user.email ?? "No email"
        let userFullName = user.displayName ?? "No name"
        let currentTimestamp = Timestamp(date: Date()) // Current timestamp

        // Define the fields to be stored in Firestore
        let userData: [String: Any] = [
            "createdAt": currentTimestamp,          // Timestamp of when the user was created
            "email": userEmail,                     // Email address used for sign-up
            "fullName": userFullName,               // Full name of the user (from Google account)
            "isActive": true,                       // Active status of the user (default: true)
            "phoneNumber": NSNull(),                     // Phone number (nil for now)
            "requestHistory": [],                   // Request history (empty array for now)
            "role": "student",
        ]

        // Store the user data in Firestore
        let db = Firestore.firestore()
        db.collection("users").document(uid).setData(userData) { error in
            if let error = error {
                print("Error storing user data in Firestore: \(error.localizedDescription)")
            } else {
                print("User data successfully stored in Firestore!")
                // You can navigate to the main app screen or show a welcome message
            }
        }

        // You might want to show a profile setup screen or a welcome message
        self.showSignUpAlert()
    }


    // Function to show an alert or a prompt for a new user to complete their sign-up
    func showSignUpAlert() {
        let alertController = UIAlertController(
            title: "New User",
            message: "It looks like you're a new user! Welcome :)",
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            // Navigate to profile setup screen or other necessary actions
            self.navigateToProfileSetup()
        }))
        
        self.present(alertController, animated: true, completion: nil)
    }

    // Example function to navigate to a profile setup screen
    func navigateToProfileSetup() {
        // Here, you can segue to a profile setup screen or show a form to complete the user's profile
        print("Navigating to profile setup screen...")
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
