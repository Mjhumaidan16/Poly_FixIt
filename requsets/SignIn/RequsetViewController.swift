//
//  RequsetViewController.swift
//  SignIn
//
//  Created by BP-36-212-05 on 14/12/2025.
//


import UIKit
import FirebaseFirestore

class RequsetViewController: UIViewController {
    
    // MARK: - IBOutlets for Text Fields and Button
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var descriptionTextField: UITextField!
    @IBOutlet weak var locationTextField: UITextField!
    //@IBOutlet weak var categoryTextField: UITextField!
    @IBOutlet weak var submitButton: UIButton!
    
    // Firestore reference
    private let db = Firestore.firestore()
    
    // Example of custom keyboard
    private var customKeyboard: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Safe unwrapping example
        if titleTextField == nil || descriptionTextField == nil || locationTextField == nil {
            print("One or more are not connected properly!")
            // Optionally, set up the custom keyboard here if needed
        }
    }
    
    // MARK: - IBAction for Submit Button
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        print("Submit button tapped!")  // Add logging here
        
        guard let title = titleTextField.text, !title.isEmpty,
              let description = descriptionTextField.text, !description.isEmpty,
              let location = locationTextField.text, !location.isEmpty else {
            showAlert(message: "Please fill in all fields.")
            return
        }
        
        // Assuming categoryIndex needs to be an integer
        // Here, we could convert the category to an index or use it as a string
        //let categoryIndex = getCategoryIndex(from: category)
        
        // Firestore reference to user document
        let userRef = Firestore.firestore().collection("users").document("exampleUserId") // Example user ID
        
        let newRequest = RequestCreateDTO(
            title: title,
            description: description,
            location: location,
            categoryIndex: 0,
            priorityIndex: 0,
            submittedBy: userRef
        )
        
        // Log the new request data
        print("New request data: \(newRequest)")  // Add logging to see the data you're sending
        
        // Async Task to add the request
        Task {
            do {
                print("Attempting to add request...")  // Log before Firestore call
                let documentId = try await RequestManager.shared.addRequest(newRequest)
                print("New request added with ID: \(documentId)")  // Log success
                
                // Clear text fields after successful submission
                titleTextField.text = ""
                descriptionTextField.text = ""
                //categoryTextField.text = ""
                
                // Optionally show an alert confirming the request was added
                showAlert(message: "Your request has been submitted successfully.")
                
            } catch {
                print("Error adding request: \(error.localizedDescription)")  // Log error
                showAlert(message: "Failed to submit request. Please try again.")
            }
        }
    }
    
    // MARK: - Helper Method for Showing Alerts
    func showAlert(message: String) {
        let alertController = UIAlertController(title: "Notification", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    // Helper function to get category index (you can adapt this based on your logic)
    func getCategoryIndex(from category: String) -> Int {
        // Example mapping of categories to indices
        let categories = ["General", "Urgent", "Low Priority", "High Priority"]
        
        if let index = categories.firstIndex(of: category) {
            return index
        } else {
            // Default category if not found
            return 0
        }
    }
}
