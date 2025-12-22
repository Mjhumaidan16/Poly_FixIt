import UIKit
import FirebaseFirestore
import FirebaseAuth
import Cloudinary

private var uploadedImageUrl: String?
private var selectedImage: UIImage?
private let uploadPreset = "iOS_requests_preset" // Cloudinary upload preset

final class AddRequsetViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var descriptionTextField: UITextField!
    @IBOutlet weak var categoryButton: UIButton!
    /// Single picker with 3 components: Campus / Building / Room (Room = Class)
    @IBOutlet weak var locationPickerView: UIPickerView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var submitButton: UIButton!

    // MARK: - Properties
    private let db = Firestore.firestore()
    private var uploadedImagePublicId: String?

    // ✅ Campus -> Buildings
    private let buildingsByCampus: [String: [String]] = [
        "CampusA": ["19", "36", "25"],
        "CampusB": ["20", "25"]
    ]

    // ✅ Building -> 4 Classes (edit these names as you want)
    private let classesByBuilding: [String: [String]] = [
        "19": ["01", "02", "03", "04"],
        "36": ["101", "102", "103", "104"],
        "25": ["313", "314", "315", "316"],
        "20": ["98", "99", "100", "101"]
    ]

    private var categories: [String] = []
    private var campus: [String] = []
    private var building: [String] = []
    private var room: [String] = []   // ✅ this now holds CLASSES

    private var selectedCategory: String?
    private var selectedCategoryName: String?
    private var selectedCampus: String?
    private var selectedBuilding: String?
    private var selectedRoom: String?  // ✅ selected class

    private var uploadedImageUrl: String?
    private var userId: String = ""

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set delegates and data sources
        locationPickerView.delegate = self
        locationPickerView.dataSource = self

        // ✅ Load campuses
        campus = Array(buildingsByCampus.keys)
        selectedCampus = campus.first

        if let selectedCampus = selectedCampus {
            loadBuildingsAndRooms(forCampus: selectedCampus)
        }

        // Reload picker initially
        locationPickerView.reloadAllComponents()

        fetchSharedSettings() // Fetch shared settings from the "requests/001" document

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageViewTapped))
        imageView.addGestureRecognizer(tapGesture)
        imageView.isUserInteractionEnabled = true
    }

    // MARK: - Fetch Shared Settings (from "requests/001" document)
    func fetchSharedSettings() {
        db.collection("requests").document("xnPtlNRUYzdPMB5GeXwf").getDocument { snapshot, error in
            if let error = error {
                print("Error fetching shared settings: \(error)")
                return
            }

            guard let data = snapshot?.data() else {
                print("No shared settings found in 'requests/001'.")
                return
            }

            if let categories = data["category"] as? [String] {
                self.categories = categories
            } else {
                print("Categories not found in 'requests/001'.")
            }

            self.setupCategoryMenu()
        }
    }

    // MARK: - Load buildings and classes based on selected campus
    private func loadBuildingsAndRooms(forCampus campus: String) {
        // ✅ Buildings for campus
        self.building = buildingsByCampus[campus] ?? []
        self.selectedBuilding = building.first

        // ✅ Classes for the selected building (component 2)
        if let b = self.selectedBuilding {
            self.room = classesByBuilding[b] ?? []
        } else {
            self.room = []
        }
        self.selectedRoom = room.first

        DispatchQueue.main.async {
            self.locationPickerView.reloadComponent(1) // buildings
            self.locationPickerView.reloadComponent(2) // classes
            self.locationPickerView.selectRow(0, inComponent: 1, animated: true)
            self.locationPickerView.selectRow(0, inComponent: 2, animated: true)
        }
    }

    // MARK: - UIPickerView DataSource
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
            guard campus.indices.contains(row) else { return }
            selectedCampus = campus[row]
            if let selectedCampus {
                loadBuildingsAndRooms(forCampus: selectedCampus)
            }

        case 1:
            guard building.indices.contains(row) else { return }
            selectedBuilding = building[row]

            // ✅ Building changed -> reload classes (component 2)
            let newClasses = classesByBuilding[selectedBuilding ?? ""] ?? []
            room = newClasses
            selectedRoom = room.first

            pickerView.reloadComponent(2)
            pickerView.selectRow(0, inComponent: 2, animated: true)

        case 2:
            guard room.indices.contains(row) else { return }
            selectedRoom = room[row]

        default:
            break
        }
    }

    // MARK: - Image View Tap Action
    @objc func imageViewTapped() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        present(picker, animated: true)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
    ) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage else { return }
        imageView.image = image
        selectedImage = image
    }

    // MARK: - Upload to Cloudinary (using unsigned upload preset)
    private func uploadToCloudinary(
        image: UIImage,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        AppDelegate.cloudinary.createUploader()
            .upload(data: data, uploadPreset: uploadPreset, completionHandler: { response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(.failure(error))
                        return
                    }

                    guard let url = response?.secureUrl else {
                        completion(.failure(NSError(domain: "", code: -1)))
                        return
                    }

                    completion(.success(url))
                }
            })
    }

    // MARK: - Submit Action
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        guard validateFields() else { return }
        guard let image = selectedImage else {
            showAlert("Please select an image.")
            return
        }

        sender.isEnabled = false

        uploadToCloudinary(image: image) { [weak self] result in
            guard let self = self else { return }
            sender.isEnabled = true

            switch result {
            case .failure:
                self.showAlert("Image upload failed ❌")
            case .success(let imageUrl):
                self.submitRequest(with: imageUrl)
            }
        }
    }

    private func submitRequest(with imageUrl: String) {
        userId = "bmVxgwiDv3MIFMLWgfb7hxOrHsl2"

        guard
            let selectedCampus = selectedCampus,
            let selectedBuilding = selectedBuilding,
            let selectedRoom = selectedRoom
        else {
            showAlert("Please complete all selections.")
            return
        }

        let request = RequestCreateDTO(
            title: titleTextField.text!,
            description: descriptionTextField.text!,
            location: [
                "campus": [selectedCampus],
                "building": [selectedBuilding],
                "room": [selectedRoom]   // ✅ this is the selected class now
            ],
            category: ["IT",
                       "pluming",
                       "HVAC",
                       "Furniture",
                       "Safety"],
            priorityLevel: ["high",
                            "middel",
                            "low"],
            selectedCategory: "IT",
            selectedPriorityLevel: "low",
            imageUrl: imageUrl,
            submittedBy: db.collection("users").document("bmVxgwiDv3MIFMLWgfb7hxOrHsl2"),
            assignedTechnician: nil,
            relatedTickets: [],
            status: "Pending",
            acceptanceTime: nil,
            completionTime: nil,
            assignedAt: nil,
            duplicateFlag: false,
            createdAt: Timestamp()
        )

        Task {
            do {
                userId = try await RequestManager.shared.addRequest(request)
                print("Request submitted with ID: \(userId)")
                showAlert("Request submitted successfully ✅")
            } catch {
                showAlert("Failed to submit request ❌")
            }
        }
    }

    // MARK: - Category Setup
    private func setupCategoryMenu() {
        guard !categories.isEmpty else {
            print("No categories available to setup menu.")
            return
        }

        let actions = categories.map { (category) in
            UIAction(title: category) { [weak self] _ in
                self?.selectedCategory = category
                self?.categoryButton.setTitle(category, for: .normal)
                print("Category selected: \(self?.selectedCategory ?? "None")")
            }
        }

        categoryButton.menu = UIMenu(title: "Select Category", children: actions)
        categoryButton.showsMenuAsPrimaryAction = true
    }

    // MARK: - Helpers
    private func validateFields() -> Bool {
        guard
            let title = titleTextField.text, !title.isEmpty,
            let description = descriptionTextField.text, !description.isEmpty,
            selectedCampus != nil,
            selectedRoom != nil,
            selectedBuilding != nil
        else {
            showAlert("Please fill all fields.")
            return false
        }
        return true
    }

    private func clearFields() {
        titleTextField.text = ""
        descriptionTextField.text = ""

        selectedCategoryName = nil
        selectedCampus = nil
        selectedBuilding = nil
        selectedRoom = nil
        uploadedImageUrl = nil

        categoryButton.setTitle("Select Category", for: .normal)
        locationPickerView.reloadAllComponents()
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(
            title: "Notice",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
