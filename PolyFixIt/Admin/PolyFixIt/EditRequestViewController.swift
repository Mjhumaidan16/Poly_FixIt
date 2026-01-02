import UIKit
import FirebaseFirestore
import FirebaseAuth
import Cloudinary

private var selectedImage: UIImage?
private let uploadPreset = "iOS_requests_preset"


final class EditRequestViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // MARK: - Passed in
    var userId: String!
    // MARK: - IBOutlets
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var descriptionTextView: UITextView!
    @IBOutlet weak var CategoryButton: UIButton!
    @IBOutlet var PriorityLevelButton: UIButton! // NEW
    @IBOutlet weak var LocationPickerView: UIPickerView!
    @IBOutlet weak var submitButton: UIButton!

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

    private let categories: [String] = ["Plumbing", "IT", "HVAC", "Furniture", "Safety"]
    private var priorityLevels: [String] = ["high", "middel", "low"]
    private var campus: [String] = []
    private var building: [String] = []
    private var room: [String] = []

    private var selectedCategory: String?
    private var selectedPriorityLevel: String?
    private var selectedCampus: String?
    private var selectedBuilding: String?
    private var selectedRoom: String?



    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad called")
        
        precondition(titleTextField != nil, "titleTextField outlet is not connected")
        precondition(descriptionTextView != nil, "descriptionTextField outlet is not connected")
        precondition(CategoryButton != nil, "categoryButton outlet is not connected")
        precondition(PriorityLevelButton != nil, "priorityLevelButton outlet is not connected") // NEW
        precondition(LocationPickerView != nil, "locationPickerView outlet is not connected")
        precondition(submitButton != nil, "submitButton outlet is not connected")
        
       
        
        LocationPickerView.delegate = self
        LocationPickerView.dataSource = self
        
        campus = Array(buildingsByCampus.keys)
        selectedCampus = campus.first
        if let selectedCampus = selectedCampus {
            loadBuildingsAndRooms(forCampus: selectedCampus)
        }
        LocationPickerView.reloadAllComponents()
        
        // Prevent a crash if this screen is opened without a request id.
        guard let requestId = userId, !requestId.isEmpty else {
            print("❌ EditRequestViewController opened without userId/requestId")
            disableEditing()
            showAlert("Missing request id. Please open this screen from a request.")
            return
        }

        fetchRequestDataFromManager(requestId: requestId)

        
    }

    private func fetchRequestDataFromManager(requestId: String) {
        RequestManager.shared.fetchRequest(requestId: requestId) { [weak self] request in
            guard let self = self else { return }
            guard let request = request else {
                print("Failed to fetch request.")
                return
            }

            DispatchQueue.main.async {
                self.currentRequest = request
                self.selectedCategory = request.selectedCategory
                self.selectedPriorityLevel = request.selectedPriorityLevel

                self.prefillFields(with: request)

                // IMPORTANT: menus must be configured (otherwise you’re relying on storyboard menus)
                self.setupCategoryDropdownMenu()
                self.setupPriorityMenu()

                self.enableEditing()
            }
        }
    }

    // MARK: - Setup Category Menu
    private func setupCategoryDropdownMenu() {
        let actions: [UIAction] = categories.map { category in
            UIAction(title: category, state: .off) { [weak self] _ in
                guard let self = self else { return }
                self.selectedCategory = category
                self.CategoryButton.setTitle(category, for: .normal)
            }
        }

        CategoryButton.menu = UIMenu(title: "Select Category", children: actions)
        CategoryButton.showsMenuAsPrimaryAction = true
    }
    
    // MARK: - Setup Priority Menu
    private func setupPriorityMenu() {
        guard !priorityLevels.isEmpty else { return }
        
        if selectedPriorityLevel == nil {
            selectedPriorityLevel = priorityLevels.first
            if let selectedPriorityLevel { PriorityLevelButton.setTitle(selectedPriorityLevel, for: .normal) }
        }

        let actions = priorityLevels.map { level in
            UIAction(title: level.capitalized) { [weak self] _ in
                self?.selectedPriorityLevel = level
                self?.PriorityLevelButton.setTitle(level.capitalized, for: .normal)
                print("Priority selected: \(self?.selectedPriorityLevel ?? "None")")
            }
        }

        PriorityLevelButton.menu = UIMenu(title: "Select Priority", children: actions)
        PriorityLevelButton.showsMenuAsPrimaryAction = true
    }

    // MARK: - Enable/Disable Editing
    private func enableEditing() {
        titleTextField.isEnabled = true
        descriptionTextView.isEditable = true
        CategoryButton.isEnabled = true
        PriorityLevelButton.isEnabled = true // NEW
        LocationPickerView.isUserInteractionEnabled = true
        submitButton.isEnabled = true
    }

    private func disableEditing() {
        titleTextField.isEnabled = false
        descriptionTextView.isEditable = false
        CategoryButton.isEnabled = false
        PriorityLevelButton.isEnabled = false // NEW
        LocationPickerView.isUserInteractionEnabled = false
        submitButton.isEnabled = false
    }

    // MARK: - Prefill Fields
    private func prefillFields(with request: Request) {
         titleTextField.text = request.title
         descriptionTextView.text = request.description

        if let selected = request.selectedCategory, !selected.isEmpty {
            selectedCategory = selected
            // Only set the visible title here. The dropdown menu is configured later in setupCategoryMenu().
            CategoryButton.setTitle(selected.capitalized, for: .normal)
        }

        if let selected = request.selectedPriorityLevel, !selected.isEmpty {
            selectedPriorityLevel = selected
            PriorityLevelButton.setTitle(selected.capitalized, for: .normal)
        }
       

         guard request.location.count == 3 else {
             print("❌ Invalid location array, skipping location prefill")
             return
         }

         let campusValue = request.location[0]
         let buildingValue = request.location[1]
         let roomValue = request.location[2]

         selectedCampus = campusValue
         loadBuildingsAndRooms(forCampus: campusValue)

         selectedBuilding = buildingValue
         room = classesByBuilding[buildingValue] ?? []
         selectedRoom = roomValue

         LocationPickerView.reloadAllComponents()

         if let campusIndex = campus.firstIndex(of: campusValue) {
             LocationPickerView.selectRow(campusIndex, inComponent: 0, animated: false)
         }
         if let buildingIndex = building.firstIndex(of: buildingValue) {
             LocationPickerView.selectRow(buildingIndex, inComponent: 1, animated: false)
         }
         if let roomIndex = room.firstIndex(of: roomValue) {
             LocationPickerView.selectRow(roomIndex, inComponent: 2, animated: false)
         }

        setupCategoryDropdownMenu()
        setupPriorityMenu() // NEW
    }

    // MARK: - Picker Handling
    private func loadBuildingsAndRooms(forCampus campus: String) {
        building = buildingsByCampus[campus] ?? []
        selectedBuilding = building.first
        room = selectedBuilding.flatMap { classesByBuilding[$0] } ?? []
        selectedRoom = room.first

        DispatchQueue.main.async {
            self.LocationPickerView.reloadAllComponents()
            self.LocationPickerView.selectRow(0, inComponent: 1, animated: true)
            self.LocationPickerView.selectRow(0, inComponent: 2, animated: true)
        }
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 3 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch component {
        case 0: return campus.count
        case 1: return building.count
        case 2: return room.count
        default: return 0
        }
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch component {
        case 0: return campus.indices.contains(row) ? campus[row] : nil
        case 1: return building.indices.contains(row) ? building[row] : nil
        case 2: return room.indices.contains(row) ? room[row] : nil
        default: return nil
        }
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch component {
        case 0:
            selectedCampus = campus.indices.contains(row) ? campus[row] : nil
            loadBuildingsAndRooms(forCampus: selectedCampus ?? "")
        case 1:
            selectedBuilding = building.indices.contains(row) ? building[row] : nil
            room = selectedBuilding.flatMap { classesByBuilding[$0] } ?? []
            selectedRoom = room.first
            pickerView.reloadComponent(2)
            pickerView.selectRow(0, inComponent: 2, animated: true)
        case 2:
            selectedRoom = room.indices.contains(row) ? room[row] : nil
        default: break
        }
    }

    // MARK: - Delete
    private func deleteRequestFromManager() {
        guard let requestId = userId, !requestId.isEmpty else {
            showAlert("Missing request id")
            return
        }
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

    // MARK: - Submit
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        guard validateFields() else { return }
    }

    private func validateFields() -> Bool {
        guard let title = titleTextField.text, !title.isEmpty,
              let description = descriptionTextView.text, !description.isEmpty,
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
            description: descriptionTextView.text,
            location: ["campus": [selectedCampus],
                       "building": [selectedBuilding],
                       "room": [selectedRoom]],
            category: (currentRequest?.category.isEmpty == false ? currentRequest!.category : categories),
            priorityLevel: currentRequest?.priorityLevel ?? ["high","middel","low"],
            selectedCategory: selectedCategory,
            selectedPriorityLevel: selectedPriorityLevel, // UPDATED
            imageUrl: imageUrl,
            imageProof: nil,
            submittedBy: nil,
            assignedTechnician: nil,
            assignedAdmin: nil,
            status: nil,
            acceptanceTime: nil,
            completionTime: nil,
            completionNotes: nil,
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
