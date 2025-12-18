import UIKit
import FirebaseFirestore
import FirebaseAuth
import Cloudinary

private var uploadedImageUrl: String?
private let uploadPreset = "iOS_requests_preset" // Cloudinary upload preset

final class RequestViewController2: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var descriptionTextField: UITextField!
    @IBOutlet weak var categoryButton: UIButton!
    @IBOutlet weak var campusPickerView: UIPickerView!
    @IBOutlet weak var buildingPickerView: UIPickerView!
    @IBOutlet weak var roomPickerView: UIPickerView!
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
    
    private var selectedCategoryIndex: Int?
    private var selectedCategoryName: String?
    private var selectedCampus: String?
    private var selectedBuilding: String?
    private var selectedRoom: String?
    
    private var uploadedImageUrl: String?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set delegates and data sources
        campusPickerView.delegate = self
        campusPickerView.dataSource = self
        buildingPickerView.delegate = self
        buildingPickerView.dataSource = self
        roomPickerView.delegate = self
        roomPickerView.dataSource = self
        
        // Load campus data and set default campus (Campus A)
             campus = Array(campusData.keys)  // Get all campus names
             selectedCampus = campus.first    // Default to the first campus, "campusA"
             
             loadBuildingsAndRooms(forCampus: selectedCampus!)

        // Reload pickers initially
        campusPickerView.reloadAllComponents()
        buildingPickerView.reloadAllComponents()
        roomPickerView.reloadAllComponents()
        
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
                self.buildingPickerView.reloadAllComponents()
                self.roomPickerView.reloadAllComponents()
            }
        }

    // MARK: - UIPickerView DataSource
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == campusPickerView {
            return campus.count
        } else if pickerView == buildingPickerView {
            return building.count
        } else {
            return room.count
        }
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == campusPickerView {
            return campus[row]
        } else if pickerView == buildingPickerView {
            return building[row]
        } else {
            return room[row]
        }
    }


    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            if pickerView == campusPickerView {
                selectedCampus = campus[row]
                print("Selected Campus:", selectedCampus)
                loadBuildingsAndRooms(forCampus: selectedCampus!)
            } else if pickerView == buildingPickerView {
                selectedBuilding = building[row]
                print("Selected Building:", selectedBuilding)
            } else if pickerView == roomPickerView {
                selectedRoom = room[row]
                print("Selected Room:", selectedRoom)
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

        // MARK: - UIImagePickerControllerDelegate
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)

            // Retrieve the selected image
            guard let selectedImage = info[.originalImage] as? UIImage else { return }
            
            // Set the selected image to the imageView
            imageView.image = selectedImage

            // Optionally upload to Cloudinary
            uploadToCloudinary(image: selectedImage)
        }

    // MARK: - Upload to Cloudinary (using unsigned upload preset)
    private func uploadToCloudinary(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        // Cloudinary Unsigned Upload
        AppDelegate.cloudinary.createUploader()
            .upload(data: data, uploadPreset: uploadPreset, completionHandler: { response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Cloudinary upload failed:", error.localizedDescription)
                        self.showAlert("Image upload failed ❌")
                        return
                    }

                    guard let secureUrl = response?.secureUrl else {
                        self.showAlert("Could not get image URL")
                        return
                    }

                    // Save the uploaded image URL
                    self.uploadedImageUrl = secureUrl
                    print("✅ Image uploaded to folder 'requests':", self.uploadedImageUrl!)
                }
            })
    }



    // MARK: - Submit Action
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        guard validateFields() else { return }
        let userId: String
        if let currentUser = Auth.auth().currentUser{
            //remove if and keep guard after
            // Use real signed-in user
               userId = currentUser.uid
               print("Authenticated user ID:", userId)
        }
        else {
            // Use mock user ID for testing
            userId = "qFwpLWvpTNhEVNDdZ9BU"
            print("Using mock user ID:", userId)
        }

        // Ensure the category index and campus are selected
        guard let selectedCategoryIndex = selectedCategoryIndex,
              let selectedCampus = selectedCampus,
              let selectedBuilding = selectedBuilding,
              let selectedRoom = selectedRoom,
              let imageUrl = uploadedImageUrl else {
            showAlert("Please complete all selections.")
            return
        }

        let request = RequestCreateDTO2(
            title: titleTextField.text!,
            description: descriptionTextField.text!,
            location: [
                    "campus": [selectedCampus],
                    "building": [selectedBuilding],
                    "room": [selectedRoom]
                ],
            categoryIndex: selectedCategoryIndex,  // Use category index
            priorityIndex: 0,
            submittedBy: db.collection("users").document("qFwpLWvpTNhEVNDdZ9BU"), // Use current user's UID
            imageUrl:imageUrl
           
        )
        
        Task {
            do {
                _ = try await RequestManager2.shared.addRequest(request)
                clearFields()
                showAlert("Request submitted successfully ✅")
            } catch {
                showAlert("Failed to submit request ❌")
            }
        }
    }

    // MARK: - Category Setup
    private func setupCategoryMenu() {
        guard let categoryButton = categoryButton else {
            print("Error: categoryButton is nil!")
            return
        }

        let actions = categories.enumerated().map { (index, category) in
            UIAction(title: category) { [weak self] _ in
                self?.selectedCategoryIndex = index
                self?.selectedCategoryName = category
                self?.categoryButton.setTitle(category, for: .normal)
            }
        }
        
        categoryButton.menu = UIMenu(
            title: "Select Category",
            children: actions
        )
    }
    // MARK: - Helpers
    private func validateFields() -> Bool {
        guard
            let title = titleTextField.text, !title.isEmpty,
            let description = descriptionTextField.text, !description.isEmpty,
            selectedCategoryIndex != nil,  // Validate category index
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
        
        selectedCategoryIndex = nil
        selectedCategoryName = nil
        selectedCampus = nil
        selectedBuilding = nil
        selectedRoom = nil
        uploadedImageUrl = nil
        
        categoryButton.setTitle("Select Category", for: .normal)
        campusPickerView.reloadAllComponents()
        buildingPickerView.reloadAllComponents()
        roomPickerView.reloadAllComponents()
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
