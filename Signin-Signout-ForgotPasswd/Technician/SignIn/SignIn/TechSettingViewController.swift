import UIKit
import FirebaseAuth
import FirebaseFirestore

/// Technician Settings / Profile screen.
///
/// This controller is wired to the storyboard scene with identifier `TechSettingViewController`.
/// It supports:
/// - Viewing technician profile fields (read-only)
/// - Tapping **Change** to enable editing, then **Submit** to save
/// - Updating Auth email (via verification flow) / password (via updatePassword)
/// - Updating Firestore document in `technicians/{uid}`
/// - Logging out and returning to the sign-in screen
final class TechSettingViewController: UIViewController {

    // MARK: - Outlets (must match storyboard)

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!

    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var changeButton: UIButton!
    @IBOutlet weak var logoutButton: UIButton!

    // MARK: - State

    private var isInEditMode: Bool = false
    private var isHandlingTap: Bool = false // prevents accidental double-fire

    private var originalEmail: String?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Ensure logout works even if storyboard action isn't wired.
        logoutButton.addTarget(self, action: #selector(logoutButtonTapped(_:)), for: .touchUpInside)

        configureReadOnlyUI()
        fetchAndPopulateTechnicianProfile()
    }

    // MARK: - UI

    private func configureReadOnlyUI() {
        setEditable(false)

        // Show a placeholder password masked by default.
        passwordTextField.text = "12345678"
        passwordTextField.isSecureTextEntry = true
        passwordTextField.isUserInteractionEnabled = false

        changeButton.setTitle("Change", for: .normal)
        statusLabel.text = ""
    }

    private func setEditable(_ editable: Bool) {
        // Name & email stay read-only in this Technician app.
        let fields = [nameTextField, emailTextField]
        fields.forEach {
            $0?.isUserInteractionEnabled = false
            $0?.alpha = 0.6
        }

        // Password field behavior is handled separately when entering/leaving edit mode.
    }

    // MARK: - Actions

    @IBAction func changeButtonTapped(_ sender: UIButton) {
        // If the button is wired + we also have other targets, prevent double-fire.
        guard !isHandlingTap else { return }
        isHandlingTap = true
        defer {
            // release next runloop tick
            DispatchQueue.main.async { [weak self] in self?.isHandlingTap = false }
        }

        if !isInEditMode {
            enterEditMode()
        } else {
            submitChanges()
        }
    }

    @objc private func logoutButtonTapped(_ sender: UIButton) {
        logoutAndReturnToSignIn(message: nil)
    }

    // MARK: - Edit Mode

    private func enterEditMode() {
        isInEditMode = true
        // Only allow password changes.
        setEditable(false)

        // Let user type password visibly in edit mode.
        passwordTextField.isUserInteractionEnabled = true
        passwordTextField.isSecureTextEntry = false
        passwordTextField.text = ""

        changeButton.setTitle("Submit", for: .normal)
        statusLabel.text = ""
    }

    private func exitEditMode() {
        isInEditMode = false
        setEditable(false)

        passwordTextField.isUserInteractionEnabled = false
        passwordTextField.isSecureTextEntry = true
        passwordTextField.text = "12345678"

        changeButton.setTitle("Change", for: .normal)
    }

    // MARK: - Fetch

    private func fetchAndPopulateTechnicianProfile() {
        guard let uid = Auth.auth().currentUser?.uid else {
            statusLabel.text = "Not logged in"
            return
        }

        let db = Firestore.firestore()
        db.collection("technicians").document(uid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.statusLabel.text = "Failed to load"
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
                return
            }

            guard let data = snapshot?.data() else {
                DispatchQueue.main.async {
                    self.statusLabel.text = "Profile not found"
                }
                return
            }

            let fullName = (data["fullName"] as? String) ?? ""
            let email = (data["email"] as? String) ?? ""

    
            DispatchQueue.main.async {
                self.nameTextField.text = fullName
                self.emailTextField.text = email
                self.originalEmail = email
                self.statusLabel.text = ""
            }
        }
    }

    // MARK: - Submit

    private func submitChanges() {
        guard let currentUser = Auth.auth().currentUser else {
            showAlert(title: "Error", message: "No user logged in")
            return
        }
        let newPassword = passwordTextField.text ?? ""

        // Validate password (required on submit for technician settings).
        if newPassword.isEmpty {
            statusLabel.text = "Password required"
            showAlert(title: "Invalid", message: "Please enter a new password.")
            return
        }

        if !isValidPassword(newPassword) {
            statusLabel.text = "Invalid password"
            showAlert(title: "Invalid", message: "Password must be at least 8 characters and include uppercase, lowercase, and a number.")
            return
        }

        statusLabel.text = "Updating profile..."

        // Only update Auth password (do NOT update name/email from this screen).
        updateAuthPasswordIfNeeded(currentUser: currentUser, newPassword: newPassword) { [weak self] passOK in
            guard let self = self else { return }
            if !passOK {
                self.statusLabel.text = ""
                return
            }

            DispatchQueue.main.async {
                self.statusLabel.text = "Updated"
            }

            // Logout after submit (per requirements).
            self.logoutAndReturnToSignIn(message: "Password updated. Please sign in again.")
        }
    }

    // Email updates are intentionally disabled for technicians on this screen.

    private func updateAuthPasswordIfNeeded(currentUser: User, newPassword: String, completion: @escaping (Bool) -> Void) {
        guard !newPassword.isEmpty else {
            completion(true)
            return
        }

        currentUser.updatePassword(to: newPassword) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.showAlert(title: "Password", message: error.localizedDescription)
                }
                completion(false)
                return
            }
            completion(true)
        }
    }

    // MARK: - Logout / Navigation

    private func logoutAndReturnToSignIn(message: String?) {
        SessionManager.shared.stop()
        UserDefaults.standard.removeObject(forKey: "loggedInTech")
        do { try Auth.auth().signOut() } catch { /* ignore */ }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let message = message {
                self.statusLabel.text = message
            }
            self.exitEditMode()

            // Reset root to storyboard initial navigation controller.
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let initialVC = storyboard.instantiateInitialViewController()
            if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate,
               let window = sceneDelegate.window {
                window.rootViewController = initialVC
                window.makeKeyAndVisible()
            } else {
                // Fallback: pop to root if embedded in nav.
                self.navigationController?.popToRootViewController(animated: true)
            }
        }
    }

    // MARK: - Validation

    private func isValidEmail(_ email: String) -> Bool {
        // Basic email validation similar to signup.
        let regex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: email)
    }

    private func isValidPassword(_ password: String) -> Bool {
        // Minimum 8 characters, 1 uppercase, 1 lowercase, 1 number
        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,}$"
        return NSPredicate(format: "SELF MATCHES %@", passwordRegex).evaluate(with: password)
    }

    // MARK: - Alerts

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
}
