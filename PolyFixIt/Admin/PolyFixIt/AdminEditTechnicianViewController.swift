//
//  AdminEditTechnicianViewController.swift
//  SignIn
//
//  Created by BP-36-212-19 on 24/12/2025.
//

import UIKit
import FirebaseFirestore

final class AdminEditTechnicianViewController: UIViewController {

    // MARK: - Passed in
    var technicianUID: String!

    // MARK: - Outlets (these already exist in storyboard connections)
    @IBOutlet weak var fullNameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var departmentButton: UIButton!
    @IBOutlet weak var continueButton: UIButton!

    private let db = Firestore.firestore()

    private let departments = ["Plumbing", "IT", "HVAC", "Furniture", "Safety"]
    private var selectedDepartment: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Password cannot be fetched from Firebase/Auth (not readable)
        passwordTextField.text = ""
        passwordTextField.placeholder = "Enter new password (optional)"

        setupDepartmentMenu()
        fetchAndFill()
    }

    private func fetchAndFill() {
        guard let uid = technicianUID, !uid.isEmpty else {
            showAlert(title: "Error", message: "Missing technician UID.")
            return
        }

        db.collection("technicians").document(uid).getDocument { [weak self] snap, error in
            guard let self = self else { return }

            if let error = error {
                self.showAlert(title: "Fetch Failed", message: error.localizedDescription)
                return
            }

            guard let data = snap?.data() else {
                self.showAlert(title: "Not Found", message: "Technician document not found.")
                return
            }

            let fullName = (data["fullName"] as? String) ?? ""
            let email = (data["email"] as? String) ?? ""
            let dept = (data["Department"] as? String) ?? ""

            DispatchQueue.main.async {
                self.fullNameTextField.text = fullName
                self.emailTextField.text = email

                self.selectedDepartment = dept.isEmpty ? nil : dept
                self.updateDepartmentButtonTitle()
            }
        }
    }

    // MARK: - Department menu
    private func setupDepartmentMenu() {
        let actions = departments.map { dept in
            UIAction(title: dept) { [weak self] _ in
                self?.selectedDepartment = dept
                self?.updateDepartmentButtonTitle()
            }
        }
        departmentButton.menu = UIMenu(children: actions)
        departmentButton.showsMenuAsPrimaryAction = true
        updateDepartmentButtonTitle()
    }

    private func updateDepartmentButtonTitle() {
        let title = selectedDepartment ?? "Select"
        if var config = departmentButton.configuration {
            config.title = " \(title) "
            departmentButton.configuration = config
        } else {
            departmentButton.setTitle(" \(title) ", for: .normal)
        }
    }

    //Password Regex Validation
    // Rules:
    // - min 8 chars
    // - at least 1 uppercase, 1 lowercase, 1 number
    // - allowed chars: letters, numbers, underscore
    // Example valid: Huss_390370855
    private func isValidPassword(_ password: String) -> Bool {
        let regex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)[A-Za-z\\d_]{8,}$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: password)
    }

    // MARK: - Save (optional but useful)
    @IBAction func continueButtonTapped(_ sender: Any) {
        guard let uid = technicianUID, !uid.isEmpty else { return }

        let fullName = (fullNameTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let email = (emailTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let dept = (selectedDepartment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if fullName.isEmpty || email.isEmpty || dept.isEmpty {
            showAlert(title: "Missing Info", message: "Full name, email, and department are required.")
            return
        }

        //Validate password only if admin entered one
        let password = (passwordTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !password.isEmpty && !isValidPassword(password) {
            showAlert(
                title: "Invalid Password",
                message: """
                Password must:
                • Be at least 8 characters
                • Contain uppercase & lowercase letters
                • Contain at least one number
                • Only use letters, numbers, or _
                """
            )
            return
        }

        // NOTE: password cannot be changed for another user from iOS client.
        // We'll ignore password here (or you can add Cloud Function later).

        db.collection("technicians").document(uid).updateData([
            "fullName": fullName,
            "email": email,
            "Department": dept
        ]) { [weak self] error in
            if let error = error {
                self?.showAlert(title: "Update Failed", message: error.localizedDescription)
                return
            }
            self?.showAlert(title: "Updated", message: "Technician info updated.")
        }
    }

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(a, animated: true)
        }
    }
}
