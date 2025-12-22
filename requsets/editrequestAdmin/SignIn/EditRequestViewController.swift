import UIKit
import FirebaseFirestore
import FirebaseAuth
import Cloudinary

private var selectedImage: UIImage?
private let uploadPreset = "iOS_requests_preset"

final class EditRequestViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var descriptionTextField: UITextField!
    @IBOutlet weak var categoryButton: UIButton!
    @IBOutlet weak var priorityLevelButton: UIButton! // NEW
    @IBOutlet weak var locationPickerView: UIPickerView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var deleteButton: UIButton!
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

    private var userId: String = "KDLMdnh21EPopn274E22"

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad called")
        
        precondition(titleTextField != nil, "titleTextField outlet is not connected")
        precondition(descriptionTextField != nil, "descriptionTextField outlet is not connected")
        precondition(categoryButton != nil, "categoryButton outlet is not connected")
        precondition(priorityLevelButton != nil, "priorityLevelButton outlet is not connected") // NEW
        precondition(locationPickerView != nil, "locationPickerView outlet is not connected")
        precondition(imageView != nil, "imageView outlet is not connected")
        precondition(submitButton != nil, "submitButton outlet is not connected")
        
        setupImageTap()
        
        locationPickerView.delegate = self
        locationPickerView.dataSource = self
        
        campus = Array(buildingsByCampus.keys)
        selectedCampus = campus.first
        if let selectedCampus = selectedCampus {
            loadBuildingsAndRooms(forCampus: selectedCampus)
        }
        locationPickerView.reloadAllComponents()
        
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
                self.enableEditing()
                print("Fetched categories:", self.categories)
            } else {
                print("Failed to fetch request.")
            }
        }
    }

    // MARK: - Setup Category Menu
    private func setupCategoryMenu() {
        guard !categories.isEmpty else { return }
        
        if selectedCategory == nil {
            selectedCategory = categories.first
            if let selectedCategory { categoryButton.setTitle(selectedCategory, for: .normal) }
        }

        let actions = categories.map { category in
            UIAction(title: category) { [weak self] _ in
                self?.selectedCategory = category
                self?.categoryButton.setTitle(category, for: .normal)
            }
        }

        categoryButton.menu = UIMenu(title: "Select Category", children: actions)
        categoryButton.showsMenuAsPrimaryAction = true
    }
    
    // MARK: - Setup Priority Menu
    private func setupPriorityMenu() {
        guard !priorityLevels.isEmpty else { return }
        
        if selectedPriorityLevel == nil {
            selectedPriorityLevel = priorityLevels.first
            if let selectedPriorityLevel { priorityLevelButton.setTitle(selectedPriorityLevel, for: .normal) }
        }

        let actions = priorityLevels.map { level in
            UIAction(title: level.capitalized) { [weak self] _ in
                self?.selectedPriorityLevel = level
                self?.priorityLevelButton.setTitle(level.capitalized, for: .normal)
                print("Priority selected: \(self?.selectedPriorityLevel ?? "None")")
            }
        }

        priorityLevelButton.menu = UIMenu(title: "Select Priority", children: actions)
        priorityLevelButton.showsMenuAsPrimaryAction = true
    }

    // MARK: - Enable/Disable Editing
    private func enableEditing() {
        titleTextField.isEnabled = true
        descriptionTextField.isEnabled = true
        categoryButton.isEnabled = true
        priorityLevelButton.isEnabled = true // NEW
        locationPickerView.isUserInteractionEnabled = true
        submitButton.isEnabled = true
    }

    private func disableEditing() {
        titleTextField.isEnabled = false
        descriptionTextField.isEnabled = false
        categoryButton.isEnabled = false
        priorityLevelButton.isEnabled = false // NEW
        locationPickerView.isUserInteractionEnabled = false
        submitButton.isEnabled = false
    }

    // MARK: - Prefill Fields
    private func prefillFields(with request: Request) {
        titleTextField.text = request.title
        descriptionTextField.text = request.description

        if let selected = request.selectedCategory, !selected.isEmpty {
            selectedCategory = selected
            categoryButton.setTitle(selected, for: .normal)
        }
        if let selected = request.selectedPriorityLevel, !selected.isEmpty {
            selectedPriorityLevel = selected
            priorityLevelButton.setTitle(selected.capitalized, for: .normal)
        }

        if let imageUrl = request.imageUrl {
            uploadedImageUrl = imageUrl
            downloadImage(from: imageUrl) { image in
                DispatchQueue.main.async { self.imageView.image = image }
            }
        }

        if let locationDict = request.location as? [String: [String]],
           let campusArray = locationDict["campus"], let buildingArray = locationDict["building"], let roomArray = locationDict["room"] {
            selectedCampus = campusArray.first
            loadBuildingsAndRooms(forCampus: selectedCampus ?? "")
            selectedBuilding = buildingArray.first
            room = selectedBuilding.flatMap { classesByBuilding[$0] } ?? []
            selectedRoom = roomArray.first
            locationPickerView.reloadAllComponents()
        }

        setupCategoryMenu()
        setupPriorityMenu() // NEW
    }

    // MARK: - Picker Handling
    private func loadBuildingsAndRooms(forCampus campus: String) {
        building = buildingsByCampus[campus] ?? []
        selectedBuilding = building.first
        room = selectedBuilding.flatMap { classesByBuilding[$0] } ?? []
        selectedRoom = room.first

        DispatchQueue.main.async {
            self.locationPickerView.reloadAllComponents()
            self.locationPickerView.selectRow(0, inComponent: 1, animated: true)
            self.locationPickerView.selectRow(0, inComponent: 2, animated: true)
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

    // MARK: - Image Handling
    private func setupImageTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(tap)
    }

    @objc private func imageTapped() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        imageView.image = image
        selectedImage = image
        didPickNewImage = true
    }

    func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else { completion(nil); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data, let image = UIImage(data: data) { completion(image) }
            else { completion(nil) }
        }.resume()
    }

    private func uploadToCloudinary(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        AppDelegate.cloudinary.createUploader()
            .upload(data: data, uploadPreset: uploadPreset , completionHandler:  { response, error in
                DispatchQueue.main.async {
                    if let error = error { completion(.failure(error)); return }
                    guard let url = response?.secureUrl else {
                        completion(.failure(NSError(domain: "", code: -1)))
                        return
                    }
                    completion(.success(url))
                }
            })
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

    // MARK: - Submit
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        guard validateFields() else { return }
        if didPickNewImage, let image = selectedImage {
            uploadToCloudinary(image: image) { [weak self] result in
                switch result {
                case .success(let url): self?.performUpdate(imageUrl: url)
                case .failure: self?.showAlert("Image upload failed ❌")
                }
            }
        } else {
            performUpdate(imageUrl: uploadedImageUrl ?? "")
        }
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
