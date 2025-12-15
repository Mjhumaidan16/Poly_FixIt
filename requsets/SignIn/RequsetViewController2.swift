//
//  RequsetViewController.swift
//  SignIn
//
//  Created by BP-36-212-05 on 14/12/2025.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

final class RequestViewController2: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var descriptionTextField: UITextField!
    @IBOutlet weak var categoryPickerView: UIPickerView!
    @IBOutlet weak var locationPickerView: UIPickerView!
    @IBOutlet weak var submitButton: UIButton!

    // MARK: - Properties
    private let db = Firestore.firestore()
    private var categories: [String] = []
    private var locations: [String] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        categoryPickerView.delegate = self
        categoryPickerView.dataSource = self
        locationPickerView.delegate = self
        locationPickerView.dataSource = self

        fetchCategories()
        fetchLocations()
    }

    // MARK: - Submit
    @IBAction func submitButtonTapped(_ sender: UIButton) {

        guard validateFields() else { return }

        guard let currentUser = Auth.auth().currentUser else {
            showAlert("You must be signed in.")
            return
        }

        let selectedCategoryIndex = categoryPickerView.selectedRow(inComponent: 0)
        let selectedLocationIndex = locationPickerView.selectedRow(inComponent: 0)

        let request = RequestCreateDTO(
            title: titleTextField.text!,
            description: descriptionTextField.text!,
            location: locations[selectedLocationIndex],
            categoryIndex: selectedCategoryIndex,
            priorityIndex: 0,
            submittedBy: db.collection("users").document(currentUser.uid)
        )

        Task {
            do {
                _ = try await RequestManager.shared.addRequest(request)
                clearFields()
                showAlert("Request submitted successfully ✅")
            } catch {
                showAlert("Failed to submit request ❌")
            }
        }
    }
}

// MARK: - PickerView
extension RequestViewController2: UIPickerViewDelegate, UIPickerViewDataSource {

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        pickerView == categoryPickerView ? categories.count : locations.count
    }

    func pickerView(_ pickerView: UIPickerView,
                    titleForRow row: Int,
                    forComponent component: Int) -> String? {
        pickerView == categoryPickerView ? categories[row] : locations[row]
    }
}

// MARK: - Firestore Fetch
private extension RequestViewController2 {

    func fetchCategories() {
        db.collection("categories").getDocuments { snapshot, error in
            if let error = error {
                print("Category fetch error:", error)
                return
            }
            self.categories = snapshot?.documents.compactMap {
                $0["name"] as? String
            } ?? []

            DispatchQueue.main.async {
                self.categoryPickerView.reloadAllComponents()
            }
        }
    }

    func fetchLocations() {
        db.collection("locations").getDocuments { snapshot, error in
            if let error = error {
                print("Location fetch error:", error)
                return
            }
            self.locations = snapshot?.documents.compactMap {
                $0["name"] as? String
            } ?? []

            DispatchQueue.main.async {
                self.locationPickerView.reloadAllComponents()
            }
        }
    }
}

// MARK: - Helpers
private extension RequestViewController2 {

    func validateFields() -> Bool {
        guard
            let title = titleTextField.text, !title.isEmpty,
            let description = descriptionTextField.text, !description.isEmpty,
            !categories.isEmpty,
            !locations.isEmpty
        else {
            showAlert("Please fill all fields.")
            return false
        }
        return true
    }

    func clearFields() {
        titleTextField.text = ""
        descriptionTextField.text = ""
    }

    func showAlert(_ message: String) {
        let alert = UIAlertController(
            title: "Notice",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

