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
    /// Single picker with 3 components: Campus / Building / Room
    @IBOutlet weak var locationPickerView: UIPickerView!
    @IBOutlet weak var imageView: UIImageView!      // The single image view used for both selecting and displaying the image
    @IBOutlet weak var submitButton: UIButton!

    // MARK: - Properties
    private let db = Firestore.firestore()
    private var uploadedImagePublicId: String?

    
    // Hardcoded data for campuses, buildings, and rooms
      private let campusData: [String: [String: [String]]] = [
          "campusA": [
              "buildings": ["19", "36", "25"],
              "rooms": ["100", "110", "200", "210"]
          ],
          "campusB": [
              "buildings": ["20", "25"],
              "rooms": ["100", "200", "300"]
          ]
      ]
    
    private var categories: [String] = []
    private var campus: [String] = []
    private var building: [String] = []
    private var room: [String] = []
    
    private var selectedCategory: String?
    private var selectedCategoryName: String?
    private var selectedCampus: String?
    private var selectedBuilding: String?
    private var selectedRoom: String?
    
    private var uploadedImageUrl: String?
    private var userId: String = ""

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set delegates and data sources
        locationPickerView.delegate = self
        locationPickerView.dataSource = self
        
        // Load campus data and set default campus (Campus A)
             campus = Array(campusData.keys)  // Get all campus names
             selectedCampus = campus.first    // Default to the first campus, "campusA"
             
             loadBuildingsAndRooms(forCampus: selectedCampus!)

        // Reload picker initially
        locationPickerView.reloadAllComponents()
        
        fetchSharedSettings() // Fetch shared settings from the "requests/001" document
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageViewTapped))
              imageView.addGestureRecognizer(tapGesture)
              imageView.isUserInteractionEnabled = true  // Make sure the imageView is interactive
    }

    // MARK: - Fetch Shared Settings (from "requests/001" document)
    func fetchSharedSettings() {
        // Fetching the shared settings from the `requests/001` document
        db.collection("requests").document("001").getDocument { snapshot, error in
            if let error = error {
                print("Error fetching shared settings: \(error)")
                return
            }
            
            guard let data = snapshot?.data() else {
                print("No shared settings found in 'requests/001'.")
                return
            }
            
            // Fetch categories, campuses, buildings, and rooms
            if let categories = data["category"] as? [String] {
                self.categories = categories
            } else {
                print("Categories not found in 'requests/001'.")
            }
            
            self.setupCategoryMenu() // Setup category button after loading categories
        }
    }
    
    // MARK: - Load buildings and rooms based on selected campus
        private func loadBuildingsAndRooms(forCampus campus: String) {
            guard let campusInfo = campusData[campus] else { return }
            
            // Get buildings and rooms for the selected campus
            self.building = campusInfo["buildings"] ?? []
            self.room = campusInfo["rooms"] ?? []
            
            // Set default building and room (optional)
            self.selectedBuilding = building.first
            self.selectedRoom = room.first
            
            // Reload building and room pickers
            DispatchQueue.main.async {
                // Component 1 = building, Component 2 = room
                self.locationPickerView.reloadComponent(1)
                self.locationPickerView.reloadComponent(2)

                // Keep selections valid after campus changes
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
        case 0: return campus[row]
        case 1: return building[row]
        case 2: return room[row]
        default: return nil
        }
    }


    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch component {
        case 0:
            selectedCampus = campus[row]
            if let selectedCampus {
                loadBuildingsAndRooms(forCampus: selectedCampus)
            }
        case 1:
            guard building.indices.contains(row) else { return }
            selectedBuilding = building[row]
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
            present(picker, animated: true) // Present the image picker
        }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
    ) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage else { return }
        imageView.image = image
        selectedImage = image   // 👈 store only
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

        // Optional: disable button to prevent double taps
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

        guard // selectedCategory = selectedCategory,
              let selectedCampus = selectedCampus,
              let selectedBuilding = selectedBuilding,
              let selectedRoom = selectedRoom else {
            showAlert("Please complete all selections.")
            return
        }

        let request = RequestCreateDTO(
            title: titleTextField.text!,
            description: descriptionTextField.text!,
            location: [
                "campus": [selectedCampus],
                "building": [selectedBuilding],
                "room": [selectedRoom]
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
                print("Request submitted with ID: \(userId)")  // You can log the ID or use it somewhere
                //clearFields()
                showAlert("Request submitted successfully ✅")
            } catch {
                showAlert("Failed to submit request ❌")
            }
        }

    }



    // MARK: - Category Setup
    private func setupCategoryMenu() {
        // Ensure categories is not empty before setting up the menu
        guard !categories.isEmpty else {
            print("No categories available to setup menu.")
            return
        }

        print("Categories available: \(categories)")

        // Creating actions for each category
        let actions = categories.map { (category) in
            print("Creating action for category: \(category)")

            return UIAction(title: category) { [weak self] _ in
                self?.selectedCategory = category  // Set selectedCategory to category
                self?.categoryButton.setTitle(category, for: .normal)
                print("Category selected: \(self?.selectedCategory ?? "None")")
            }
        }

        // Assign menu (iOS 14+). In storyboard you should also enable "Shows Menu as Primary Action".
        categoryButton.menu = UIMenu(title: "Select Category", children: actions)
        categoryButton.showsMenuAsPrimaryAction = true
        print("Menu assigned to categoryButton.")
    }
    // MARK: - Helpers
    private func validateFields() -> Bool {
        guard
            let title = titleTextField.text, !title.isEmpty,
            let description = descriptionTextField.text, !description.isEmpty,
            //selectedCategory != nil,  // Validate category index
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
        
        //selectedCategory = nil
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
