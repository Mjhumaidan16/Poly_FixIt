import UIKit
import FirebaseAuth
import FirebaseFirestore

class CreateTechnicianViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var fullNameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var departmentButton: UIButton!
    @IBOutlet weak var continueButton: UIButton!

    // MARK: - Properties
    private var selectedDepartment: String?
    private let db = Firestore.firestore()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureDepartmentMenu()
    }

    // MARK: - Department Menu
    private func configureDepartmentMenu() {
        let departments = [
            "Plumbing",
            "IT",
            "HVAC",
            "Furniture",
            "Safety"
        ]

        let actions = departments.map { dept in
            UIAction(title: dept) { _ in
                self.selectedDepartment = dept
                self.departmentButton.setTitle(dept, for: .normal)
            }
        }

        departmentButton.menu = UIMenu(children: actions)
        departmentButton.showsMenuAsPrimaryAction = true
    }

    // MARK: - Continue Button
    @IBAction func continueButtonTapped(_ sender: UIButton) {

        guard
            let fullName = fullNameTextField.text, !fullName.isEmpty,
            let email = emailTextField.text, !email.isEmpty,
            let password = passwordTextField.text, !password.isEmpty,
            let department = selectedDepartment
        else {
            showAlert("All fields are required")
            return
        }

        //create Firebase Auth user
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                self.showAlert("Auth Error: \(error.localizedDescription)")
                return
            }

            guard let uid = result?.user.uid else {
                self.showAlert("Failed to get user UID")
                return
            }

            //Create Firestore technician document (NO password)
            self.createTechnicianDocument(
                uid: uid,
                fullName: fullName,
                email: email,
                department: department
            )
            guard
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let window = windowScene.windows.first(where: { $0.isKeyWindow })
            else { return }

            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let loginVC = storyboard.instantiateViewController(withIdentifier: "AdminTechListViewController")
            window.rootViewController = loginVC
            window.makeKeyAndVisible()
        }
    }

    // MARK: - Firestore Creation
    private func createTechnicianDocument(
        uid: String,
        fullName: String,
        email: String,
        department: String
    ) {

        let technicianData: [String: Any] = [
            "fullName": fullName,
            "email": email,
            "Department": department,       // only the selected department
            "assignedTaskCount": 0,
            "createdAt": Timestamp(date: Date()),
            "isActive": true,
            "status": "Free"                // initial status only
        ]

        db.collection("technicians").document(uid).setData(technicianData) { error in
            if let error = error {
                self.showAlert("Firestore Error: \(error.localizedDescription)")
                return
            }

            self.showAlert("Technician account created successfully")
            self.clearFields()
        }
    }

    // MARK: - Helpers
    private func clearFields() {
        fullNameTextField.text = ""
        emailTextField.text = ""
        passwordTextField.text = ""
        departmentButton.setTitle("Select", for: .normal)
        selectedDepartment = nil
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
