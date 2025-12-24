import UIKit
import FirebaseFirestore
import FirebaseAuth
import Cloudinary

private var selectedImage: UIImage?
private let uploadPreset = "iOS_requests_preset"

final class RequestSelectionViewController: UIViewController{

    // MARK: - IBOutlets
    @IBOutlet weak var titleTextField: UILabel!
    @IBOutlet weak var descriptionTextField: UILabel!
    @IBOutlet weak var locationTextField: UILabel!
    @IBOutlet weak var categoryTextField: UILabel!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var EditButton: UIButton!

    // MARK: - Properties
    private let db = Firestore.firestore()
    private var uploadedImageUrl: String?
    private var currentRequest: Request?
    private var didPickNewImage: Bool = false

    private let buildingsByCampus: [String: [String]] = [
        "CampusA": ["19", "36", "25"],
        "CampusB": ["20", "25"]
    ]
    
    private let classesByBuilding: [String: [String]] = [
        "19": ["01", "02", "03", "04"],
        "36": ["101", "102", "103", "104"],
        "25": ["313", "314", "315", "316"],
        "20": ["98", "99", "100", "101"]
    ]

    private var categories: [String] = []
    private var priorityLevels: [String] = ["high", "middel", "low"] // Add default Firestore order
    private var campus: [String] = []
    private var building: [String] = []
    private var room: [String] = []

    private var selectedCategory: String?
    private var selectedPriorityLevel: String?
    private var selectedCampus: String?
    private var selectedBuilding: String?
    private var selectedRoom: String?

    private var userId: String = "xnPtlNRUYzdPMB5GeXwf"

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad called")
        
        precondition(titleTextField != nil, "titleTextField outlet is not connected")
        precondition(descriptionTextField != nil, "descriptionTextField outlet is not connected")
        precondition(categoryTextField != nil, "categoryButton outlet is not connected")
        precondition(locationTextField != nil, "locationPickerView outlet is not connected")
        
    
        campus = Array(buildingsByCampus.keys)
        selectedCampus = campus.first
        fetchRequestDataFromManager(requestId: userId)

        
    }

    // MARK: - Fetch Request Data
    private func fetchRequestDataFromManager(requestId: String) {
        RequestManager.shared.fetchRequest(requestId: requestId) { [weak self] request in
            guard let self = self else { return }
            if let request = request {
                self.currentRequest = request
                self.categories = request.category
                self.selectedCategory = request.selectedCategory
                self.selectedPriorityLevel = request.selectedPriorityLevel
                self.prefillFields(with: request)
           
                print("Fetched categories:", self.categories)
            } else {
                print("Failed to fetch request.")
            }
        }
    }

    // MARK: - Prefill Fields
    private func prefillFields(with request: Request) {
         titleTextField.text = request.title
         descriptionTextField.text = request.description

         if let selected = request.selectedCategory, !selected.isEmpty {
             selectedCategory = selected
             //categoryButton.setTitle(selected, for: .normal)
         }
        
        if let selected = request.selectedPriorityLevel, !selected.isEmpty {
            selectedPriorityLevel = selected
            //priorityLevelButton.setTitle(selected, for: .normal)
        }
    

         guard request.location.count == 3 else {
             print("❌ Invalid location array, skipping location prefill")
             return
         }

         let campusValue = request.location[0]
         let buildingValue = request.location[1]
         let roomValue = request.location[2]

         selectedCampus = campusValue
         //loadBuildingsAndRooms(forCampus: campusValue)

         selectedBuilding = buildingValue
         room = classesByBuilding[buildingValue] ?? []
         selectedRoom = roomValue

         }

    // MARK: - Delete
    private func deleteRequestFromManager() {
        let requestId = userId
        RequestManager.shared.deleteRequest(requestId: requestId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.showAlert("Request deleted successfully ✅")
                    self?.navigationController?.popViewController(animated: true)
                case .failure(let error):
                    self?.showAlert("Failed to delete request ❌: \(error.localizedDescription)")
                }
            }
        }
    }

    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Delete Request",
                                      message: "Are you sure you want to delete this request? This action cannot be undone.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            self?.deleteRequestFromManager()
        }))
        present(alert, animated: true)
    }
    
    
    // MARK: - Accept Request
    @IBAction func acceptButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Accept Request",
            message: "Are you sure you want to accept this request?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(
            title: "Accept",
            style: .default,
            handler: { [weak self] _ in
                self?.acceptRequestFromManager()
            }
        ))

        present(alert, animated: true)
    }

    private func acceptRequestFromManager() {
        let requestId = userId

        RequestManager.shared.updateRequestStatusOnly(
            requestId: requestId,
            status: "Accepted"
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.showAlert("Request accepted successfully ✅")
                    self?.navigationController?.popViewController(animated: true)

                case .failure(let error):
                    self?.showAlert("Failed to accept request ❌: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Submit
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        guard validateFields() else { return }
    }

    private func validateFields() -> Bool {
        guard let title = titleTextField.text, !title.isEmpty,
              let description = descriptionTextField.text, !description.isEmpty,
              selectedCategory != nil,
              selectedPriorityLevel != nil, // NEW
              selectedCampus != nil,
              selectedBuilding != nil,
              selectedRoom != nil else {
            showAlert("Please fill all fields.")
            return false
        }
        return true
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Notice", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func performUpdate(imageUrl: String) {
        guard let selectedCategory = selectedCategory,
              let selectedPriorityLevel = selectedPriorityLevel, // NEW
              let selectedCampus = selectedCampus,
              let selectedBuilding = selectedBuilding,
              let selectedRoom = selectedRoom else { return }

        let updateDTO = RequestUpdateDTO(
            title: titleTextField.text,
            description: descriptionTextField.text,
            location: ["campus": [selectedCampus],
                       "building": [selectedBuilding],
                       "room": [selectedRoom]],
            category: (currentRequest?.category.isEmpty == false ? currentRequest!.category : categories),
            priorityLevel: currentRequest?.priorityLevel ?? ["high","middel","low"],
            selectedCategory: selectedCategory,
            selectedPriorityLevel: selectedPriorityLevel, // UPDATED
            imageUrl: imageUrl,
            submittedBy: nil,
            assignedTechnician: nil,
            relatedTickets: nil,
            status: nil,
            acceptanceTime: nil,
            completionTime: nil,
            assignedAt: nil,
            duplicateFlag: nil
        )

        Task {
            do {
                try await RequestManager.shared.updateRequest(requestId: userId, updateDTO: updateDTO)
                showAlert("Request submitted successfully ✅")
            } catch {
                showAlert("Failed to submit request ❌")
            }
        }
    }
}
