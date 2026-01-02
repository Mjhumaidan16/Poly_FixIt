import UIKit
import FirebaseFirestore
import FirebaseAuth
import Cloudinary

final class AddRequsetViewController: UIViewController,
                                     UIPickerViewDelegate,
                                     UIPickerViewDataSource,
                                     UIImagePickerControllerDelegate,
                                     UINavigationControllerDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var descriptionTextField: UITextView!
    @IBOutlet weak var categoryButton: UIButton!
    @IBOutlet weak var locationPickerView: UIPickerView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var submitButton: UIButton!

    // MARK: - Properties
    private let db = Firestore.firestore()

    // Put these INSIDE the class (NOT global)
    private var uploadedImageUrl: String?
    private var selectedImage: UIImage?
    private var didUserPickImage: Bool = false

    private let uploadPreset = "iOS_requests_preset" // Cloudinary upload preset

    // HARD-CODED Categories + Priority
    private let categories: [String] = ["Plumbing", "IT", "HVAC", "Furniture", "Safety"]
    private let priorityLevels: [String] = ["high", "middel", "low"]

    private var selectedCategory: String?
    private var selectedPriorityLevel: String?

    // Campus -> Buildings
    private let buildingsByCampus: [String: [String]] = [
        "CampA": ["19", "36", "5"],
        "CampB": ["20", "25"]
    ]

    // Building -> Classes
    private let classesByBuilding: [String: [String]] = [
        "19": ["01", "02", "03", "04"],
        "36": ["101", "102", "103", "104"],
        "25": ["313", "314", "315", "316"],
        "5":  ["21", "20", "19", "19"],
        "20": ["98", "99", "100", "101"]
    ]

    private var campus: [String] = []
    private var building: [String] = []
    private var room: [String] = []

    private var selectedCampus: String?
    private var selectedBuilding: String?
    private var selectedRoom: String?

    private let defaultImageUrl = "https://res.cloudinary.com/polyfixit/image/upload/v1766424070/images-3_ufcbkf.png"

    // MARK: - Lifecycle
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        clearFields()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Delegates
        locationPickerView.delegate = self
        locationPickerView.dataSource = self

        // Load campuses
        campus = Array(buildingsByCampus.keys)
        selectedCampus = campus.first
        if let c = selectedCampus {
            loadBuildingsAndRooms(forCampus: c)
        }
        locationPickerView.reloadAllComponents()

        // Category starts empty
        selectedCategory = nil
        categoryButton.setTitle("Select Category", for: .normal)
        setupCategoryDropdownMenu()

        // Image tap
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageViewTapped))
        imageView.addGestureRecognizer(tapGesture)
        imageView.isUserInteractionEnabled = true

        // Show default image (UI only; DOES NOT count as selected)
        downloadImage(from: defaultImageUrl) { [weak self] image in
            DispatchQueue.main.async {
                self?.imageView.image = image
                self?.imageView.contentMode = .scaleAspectFit
            }
        }
    }

    // MARK: - Category Dropdown (Native iOS menu)
    private func setupCategoryDropdownMenu() {
        let actions: [UIAction] = categories.map { category in
            UIAction(title: category, state: .off) { [weak self] _ in
                guard let self = self else { return }
                self.selectedCategory = category
                self.categoryButton.setTitle(category, for: .normal)
            }
        }

        categoryButton.menu = UIMenu(title: "Select Category", children: actions)
        categoryButton.showsMenuAsPrimaryAction = true
    }

    // MARK: - Load buildings and classes based on selected campus
    private func loadBuildingsAndRooms(forCampus campus: String) {
        building = buildingsByCampus[campus] ?? []
        selectedBuilding = building.first

        if let b = selectedBuilding {
            room = classesByBuilding[b] ?? []
        } else {
            room = []
        }
        selectedRoom = room.first

        DispatchQueue.main.async {
            self.locationPickerView.reloadComponent(1)
            self.locationPickerView.reloadComponent(2)
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
            if let c = selectedCampus {
                loadBuildingsAndRooms(forCampus: c)
            }

        case 1:
            guard building.indices.contains(row) else { return }
            selectedBuilding = building[row]

            room = classesByBuilding[selectedBuilding ?? ""] ?? []
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
    @objc private func imageViewTapped() {
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

        // This is the only way to mark an image as selected for upload
        selectedImage = image
        didUserPickImage = true
    }

    // MARK: - Upload to Cloudinary
    private func uploadToCloudinary(
        image: UIImage,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "image", code: -1)))
            return
        }

        AppDelegate.cloudinary.createUploader()
            .upload(data: data, uploadPreset: uploadPreset, completionHandler:  { response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    guard let url = response?.secureUrl else {
                        completion(.failure(NSError(domain: "cloudinary", code: -2)))
                        return
                    }
                    completion(.success(url))
                }
            })
    }

    // MARK: - Image Download
    private func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else { completion(nil); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
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

        // Correct behavior for “second code”:
        // Must pick image from gallery; default image doesn't count.
        guard didUserPickImage, let image = selectedImage else {
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
        guard let currentUser = Auth.auth().currentUser else {
            showAlert("You must be logged in to submit a request.")
            return
        }

        // Ensure category is selected
        guard let category = selectedCategory, categories.contains(category) else {
            showAlert("Please select a category.")
            return
        }

        let finalPriority = selectedPriorityLevel ?? "low"

        let request = RequestCreateDTO(
            title: titleTextField.text ?? "",
            description: descriptionTextField.text ?? "",
            location: [
                "campus": [selectedCampus],
                "building": [selectedBuilding],
                "room": [selectedRoom]
            ],
            category: categories,
            priorityLevel: priorityLevels,
            selectedCategory: category,
            selectedPriorityLevel: finalPriority,
            imageUrl: imageUrl,
            imageProof: nil,
            submittedBy: db.collection("users").document(currentUser.uid),
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
                _ = try await RequestManager.shared.addRequest(request)
                clearFields()
                (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?
                    .window?.rootViewController =
                        UIStoryboard(name: "Main", bundle: nil)
                            .instantiateViewController(withIdentifier: "UserTabController")
            } catch {
                showAlert("Failed to submit request ❌")
            }
        }
    }

    // MARK: - Helpers
    private func validateFields() -> Bool {
        let title = (titleTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty, !description.isEmpty else {
            showAlert("Please fill all fields.")
            return false
        }

        guard let category = selectedCategory, categories.contains(category) else {
            showAlert("Please select a category.")
            return false
        }

        return true
    }

    private func clearFields() {
        titleTextField.text = ""
        descriptionTextField.text = ""

        // Category resets to no selection
        selectedCategory = nil
        categoryButton.setTitle("Select Category", for: .normal)
        setupCategoryDropdownMenu()

        // Optional: reset priority
        selectedPriorityLevel = nil

        // Reset location
        selectedCampus = nil
        selectedBuilding = nil
        selectedRoom = nil

        // Reset image state (this fixes the “second code” inconsistency)
        selectedImage = nil
        didUserPickImage = false

        // Show default image again (UI only)
        downloadImage(from: defaultImageUrl) { [weak self] image in
            DispatchQueue.main.async {
                self?.imageView.image = image
                self?.imageView.contentMode = .scaleAspectFit
            }
        }

        locationPickerView.reloadAllComponents()
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Notice", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
