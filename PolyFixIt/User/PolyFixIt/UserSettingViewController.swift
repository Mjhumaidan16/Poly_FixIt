import UIKit
import FirebaseAuth
import FirebaseFirestore

final class UserSettingViewController: UIViewController {

    // MARK: - IBOutlets (connect these in Main.storyboard)
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var phoneTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!

    @IBOutlet weak var changeButton: UIButton!
    @IBOutlet weak var logoutButton: UIButton!
    // Make this optional so the screen still works if you didn't add/attach a label.
    @IBOutlet weak var statusLabel: UILabel?

    // MARK: - State
    private var isEditingProfile: Bool = false
    private var isHandlingChangeTap: Bool = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Safety: If storyboard IBActions are NOT connected, ensure buttons still work.
        // If they ARE connected, adding targets here would cause the action to fire twice.
        if changeButton?.allTargets.isEmpty ?? true {
            changeButton?.addTarget(self, action: #selector(changeButtonTappedProgrammatic), for: .touchUpInside)
        }
        if logoutButton?.allTargets.isEmpty ?? true {
            logoutButton?.addTarget(self, action: #selector(logoutButtonTappedProgrammatic), for: .touchUpInside)
        }

        // Default password field content ("numbers from 1 to 8")
        passwordTextField.text = "12345678"
        passwordTextField.isSecureTextEntry = true

        // Start in read-only mode
        setEditing(enabled: false)

        // Load profile from Firestore
        fetchAndPopulateProfile()
    }
    
    private func showAlert(message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Settings",
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // If user is not logged in, bounce to login.
        guard Auth.auth().currentUser != nil else {
            goToLogin()
            return
        }
    }

    // MARK: - Actions

    /// "Change" toggles editing for name/email/phone.
    /// When editing is enabled, password field is cleared.
    @IBAction func changeButtonTapped(_ sender: UIButton) {
        // Prevent double-fire (e.g., storyboard IBAction + programmatic target both connected).
        guard !isHandlingChangeTap else { return }
        isHandlingChangeTap = true
        defer {
            // Release the guard on the next runloop tick.
            DispatchQueue.main.async { [weak self] in
                self?.isHandlingChangeTap = false
            }
        }

        // First tap: enable editing + change button title to "Submit".
        // Second tap: submit updates, then logout.
        if isEditingProfile == false {
            isEditingProfile = true
            setEditing(enabled: true)
            passwordTextField.text = ""
            passwordTextField.isSecureTextEntry = false
            statusLabel?.text = "Editing Mode"
            changeButton.setTitle("Submit", for: .normal)
        } else {
            submitProfileChangesAndLogout()
        }
    }

    /// Logout button moved from UserLoginViewController to Settings.
    @IBAction func logoutButtonTapped(_ sender: UIButton) {
        logoutAndReturnToLogin()
    }

    // MARK: - Programmatic Targets (in case storyboard actions aren't wired)

    @objc private func changeButtonTappedProgrammatic() {
        changeButtonTapped(changeButton)
    }

    @objc private func logoutButtonTappedProgrammatic() {
        logoutAndReturnToLogin()
    }

    // MARK: - Firestore

    private func fetchAndPopulateProfile() {
        guard let uid = Auth.auth().currentUser?.uid else {
            //statusLabel?.text = "No user logged in"
            return
        }

        statusLabel?.text = "Loading profile..."

        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.statusLabel?.text = "Error: \(error.localizedDescription)"
                }
                return
            }

            guard let data = snapshot?.data() else {
                DispatchQueue.main.async {
                    self.statusLabel?.text = "Profile not found"
                }
                return
            }

            // User collection field structure:
            // fullName (String), email (String), phoneNumber (Number)
            let name = (data["fullName"] as? String) ?? ""
            let email = (data["email"] as? String) ?? (Auth.auth().currentUser?.email ?? "")
            let phoneNumberAny = data["phoneNumber"]
            let phone: String
            if let n = phoneNumberAny as? Int {
                phone = String(n)
            } else if let n = phoneNumberAny as? Int64 {
                phone = String(n)
            } else if let n = phoneNumberAny as? NSNumber {
                phone = n.stringValue
            } else if let s = phoneNumberAny as? String {
                phone = s
            } else {
                phone = ""
            }

            DispatchQueue.main.async {
                self.nameTextField.text = name
                self.emailTextField.text = email
                self.phoneTextField.text = phone
                self.statusLabel?.text = "View Mode"
            }
        }
    }

    private func submitProfileChangesAndLogout() {
        guard let currentUser = Auth.auth().currentUser else {
            statusLabel?.text = "No user logged in"
            return
        }
        let uid = currentUser.uid

        let fullName = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let phoneText = phoneTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = passwordTextField.text ?? ""

        if fullName.isEmpty || email.isEmpty || phoneText.isEmpty {
            showAlert(message: "Please fill name, email, and phone number.")
            return
        }

        // Validate email and password formats using the same regex rules as SignupInputViewController.
        guard isValidEmail(email) else {
            showAlert(message: "Please enter a valid email address.")
            return
        }

        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPassword.isEmpty {
            guard isValidPassword(trimmedPassword) else {
                showAlert(message: "Password must meet the requirments.")
                return
            }
        }

        // Firestore expects phoneNumber as a number.
        guard let phoneNumber = Int64(phoneText) else {
            showAlert(message: "Phone number must be numbers only.")
            return
        }

        statusLabel?.text = "Updating profile..."

        // 1) Update Firebase Auth (email/password) if changed.
        // NOTE: Firebase may require recent login for these operations.
        let group = DispatchGroup()
        var authUpdateError: Error?

        let currentEmail = currentUser.email ?? ""
        if email != currentEmail {
            group.enter()
            currentUser.sendEmailVerification(beforeUpdatingEmail: email) { error in
                if let error = error {
                    self.showAlert(message: error.localizedDescription)
                    return
                }

                self.showAlert(message: "Verification email sent. Please verify your new email and sign in again.")
            }
        }

        if !trimmedPassword.isEmpty {
            group.enter()
            currentUser.updatePassword(to: trimmedPassword) { error in
                if let error = error { authUpdateError = error }
                group.leave()
            }
        }

        // 2) Update Firestore profile fields (do NOT store password in Firestore).
        let updates: [String: Any] = [
            "fullName": fullName,
            "email": email,
            "phoneNumber": phoneNumber
        ]

        group.notify(queue: .main) {
            if let error = authUpdateError {
                self.statusLabel?.text = "Error: \(error.localizedDescription)"
                // Common case: requires recent login
                self.showAlert(message: "Could not update account credentials: \(error.localizedDescription)\n\nPlease sign in again and retry.")
                return
            }

            Firestore.firestore().collection("users").document(uid).updateData(updates) { [weak self] error in
                guard let self = self else { return }

                if let error = error {
                    DispatchQueue.main.async {
                        self.statusLabel?.text = "Error: \(error.localizedDescription)"
                        self.showAlert(message: "Update failed: \(error.localizedDescription)")
                    }
                    return
                }

                DispatchQueue.main.async {
                    self.statusLabel?.text = "Updated. Logging out..."
                    self.logoutAndReturnToLogin()
                }
            }
        }
    }

    // MARK: - Validation (same rules as SignupInputViewController)

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailTest.evaluate(with: email)
    }

    private func isValidPassword(_ password: String) -> Bool {
        let passwordRegex = "^(?=.*[A-Z])(?=.*[a-z])(?=.*\\d)(?=.*[@$!%*?&_])[A-Za-z\\d@$!%*?&_]{8,}$"
        let passwordTest = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        return passwordTest.evaluate(with: password)
    }

    // MARK: - UI Helpers

    private func setEditing(enabled: Bool) {
        let fields = [nameTextField, emailTextField, phoneTextField]

        fields.forEach { tf in
            tf?.isUserInteractionEnabled = enabled
            tf?.backgroundColor = enabled ? .white : UIColor.systemGray5
            tf?.textColor = .label
        }

        passwordTextField.isUserInteractionEnabled = enabled
        passwordTextField.backgroundColor = enabled ? .white : UIColor.systemGray5
        passwordTextField.textColor = .label

        // Password display behavior:
        // - Default (view mode): show placeholder "12345678" masked
        // - Edit mode: show what the user types (not masked)
        if enabled {
            passwordTextField.isSecureTextEntry = false
        } else {
            passwordTextField.text = "12345678"
            passwordTextField.isSecureTextEntry = true
        }

        // Title is controlled by the change/submit logic.
        if enabled {
            // caller sets Submit
        } else {
            changeButton.setTitle("Change", for: .normal)
        }
    }

    // MARK: - Logout

    private func logoutAndReturnToLogin() {
        // Clear any locally saved login state
        UserDefaults.standard.removeObject(forKey: "loggedInUser")

        // Stop inactivity session tracking
        SessionManager.shared.stop()

        do {
            try Auth.auth().signOut()
        } catch {
            // If signOut fails, still try to return user to login.
            print("Firebase sign out error:", error.localizedDescription)
        }

        goToLogin()
    }

    private func goToLogin() {
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first(where: { $0.isKeyWindow })
        else { return }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let loginVC = storyboard.instantiateViewController(withIdentifier: "UserLoginViewController")
        window.rootViewController = loginVC
        window.makeKeyAndVisible()
    }
}


