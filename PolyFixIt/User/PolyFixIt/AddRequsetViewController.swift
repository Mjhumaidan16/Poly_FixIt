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
    @IBOutlet  var categoryButton: UIButton!
    /// Single picker with 3 components: Campus / Building / Room (Room = Class)
    @IBOutlet weak var locationPickerView: UIPickerView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet  var submitButton: UIButton!

    // MARK: - Properties
    private let db = Firestore.firestore()
    private var uploadedImagePublicId: String?

    // ✅ HARD-CODED Categories + Priority
    private let categories: [String] = ["Plumbing", "IT", "HVAC", "Furniture", "Safety"]
    private let priorityLevels: [String] = ["high", "middel", "low"]

    private var selectedCategory: String?
    private var selectedPriorityLevel: String?

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

    private var campus: [String] = []
    private var building: [String] = []
    private var room: [String] = []   // ✅ this now holds CLASSES

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

        // ✅ Default selections + menus (NO FIRESTORE)
        selectedCategory = categories.first
        selectedPriorityLevel = priorityLevels.first
        setupCategoryMenu()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageViewTapped))
        imageView.addGestureRecognizer(tapGesture)
        imageView.isUserInteractionEnabled = true

        // ✅ Set default image from Cloudinary
        let defaultImageUrl = "https://res.cloudinary.com/polyfixit/image/upload/v1766424070/images-3_ufcbkf.png"
        downloadImage(from: defaultImageUrl) { [weak self] image in
            DispatchQueue.main.async {
                self?.imageView.image = image
                self?.imageView.contentMode = .scaleAspectFit
            }
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

    // MARK: - Image Download
    func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else { completion(nil); return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data, let image = UIImage(data: data) {
                completion(image)
            } else {
                completion(nil)
            }
        }.resume()
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

        // ✅ Get current logged-in user
        guard let currentUser = Auth.auth().currentUser else {
            showAlert("You must be logged in to submit a request.")
            return
        }

        let userUID = currentUser.uid

        guard
            let selectedCampus = selectedCampus,
            let selectedBuilding = selectedBuilding,
            let selectedRoom = selectedRoom
        else {
            showAlert("Please complete all selections.")
            return
        }

        // ✅ Use selected values from menus
        let finalCategory = selectedCategory ?? categories.first ?? "IT"
        let finalPriority = selectedPriorityLevel ?? priorityLevels.first ?? "low"

        let request = RequestCreateDTO(
            title: titleTextField.text!,
            description: descriptionTextField.text!,
            location: [
                "campus": [selectedCampus],
                "building": [selectedBuilding],
                "room": [selectedRoom]
            ],
            category: categories,
            priorityLevel: priorityLevels,
            selectedCategory: finalCategory,
            selectedPriorityLevel: finalPriority,
            imageUrl: imageUrl,
            imageProof: nil,

            // ✅ CURRENT USER reference (FIX)
            submittedBy: db.collection("users").document(userUID),

            assignedTechnician: nil,
            assignedAdmin: nil,
            status: "Pending",
            acceptanceTime: nil,
            completionTime: nil,
            completionNotes: nil,
            assignedAt: nil,
            duplicateFlag: false,
            createdAt: Timestamp()
        )

        Task {
            do {
                let requestId = try await RequestManager.shared.addRequest(request)
                print("Request submitted with ID: \(requestId)")
                showAlert("Request submitted successfully ✅")
                clearFields()
            } catch {
                showAlert("Failed to submit request ❌")
            }
        }
    }

    // MARK: - Category Menu (Hardcoded, Single Selection)
    private func setupCategoryMenu() {
        // ✅ Ensure we have a default selection
        if selectedCategory == nil || !(categories.contains(selectedCategory!)) {
            selectedCategory = categories.first
        }

        let actions: [UIAction] = categories.map { category in
            UIAction(
                title: category,
                state: (category == selectedCategory) ? .on : .off
            ) { [weak self] _ in
                guard let self = self else { return }
                self.selectedCategory = category
                self.categoryButton.setTitle(category, for: .normal)
                self.setupCategoryMenu() // refresh checkmark
            }
        }

        categoryButton.menu = UIMenu(
            title: "Select Category",
            options: [.singleSelection],
            children: actions
        )
        categoryButton.showsMenuAsPrimaryAction = true
        categoryButton.setTitle(selectedCategory ?? "Select Category", for: .normal)
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

        selectedCategory = categories.first
        selectedPriorityLevel = priorityLevels.first

        selectedCampus = nil
        selectedBuilding = nil
        selectedRoom = nil
        uploadedImageUrl = nil

        setupCategoryMenu()
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
