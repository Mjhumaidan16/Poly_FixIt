import UIKit
import FirebaseFirestore
import FirebaseAuth
import Cloudinary

private var uploadedImageUrl: String?
private var selectedImage: UIImage?
private let uploadPreset = "iOS_requests_preset" // Cloudinary upload preset

final class EditRequestViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: - Injected
    private var currentRequest: Request?
    
    // MARK: - IBOutlets
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var descriptionTextField: UITextField!
    @IBOutlet weak var categoryButton: UIButton!
    @IBOutlet weak var campusPickerView: UIPickerView!
    @IBOutlet weak var buildingPickerView: UIPickerView!
    @IBOutlet weak var roomPickerView: UIPickerView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var submitButton: UIButton!

    // MARK: - Firestore
    private let db = Firestore.firestore()

    // MARK: - Hardcoded Data
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
    private var selectedCampus: String?
    private var selectedBuilding: String?
    private var selectedRoom: String?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad called")  // This will show up if viewDidLoad is being triggered
        
        setupPickers()
        setupImageTap()
        
        campus = Array(campusData.keys).sorted()

        let userId = "SWbHXFG4i7vvkOScM3K2"
        RequestManager.shared.fetchRequest(requestId: userId) { [weak self] fetchedRequest in
            print("Fetched request22:", fetchedRequest ?? "No request found")
            print("gyufgjhd",userId)

            guard let self = self else { return }

            if let request = fetchedRequest {
                self.currentRequest = request
                print("Request Status:", request.status)  // This prints the status
                if request.status != "Pending" {
                    self.showAlert("This request can no longer be edited.")
                    self.disableEditing()
                    return
                }

                self.prefillFields(with: request)
                self.fetchCategoriesAndSetupMenu()
            } else {
                self.showAlert("No request found for this user.")
            }
        }

    }





    // MARK: - Disable Editing
    private func disableEditing() {
        titleTextField.isEnabled = false
        descriptionTextField.isEnabled = false
        categoryButton.isEnabled = false
        campusPickerView.isUserInteractionEnabled = false
        buildingPickerView.isUserInteractionEnabled = false
        roomPickerView.isUserInteractionEnabled = false
        submitButton.isEnabled = false
    }

    // MARK: - Prefill Fields
    private func prefillFields(with request: Request) {
        titleTextField.text = request.title
        descriptionTextField.text = request.description
        
        if let imageUrl = request.imageUrl {
            downloadImage(from: imageUrl) { [weak self] image in
                DispatchQueue.main.async {
                    self?.imageView.image = image
                    uploadedImageUrl = imageUrl
                }
            }
        }

        if request.location.count == 3 {
            selectedCampus = request.location[0]
            selectedBuilding = request.location[1]
            selectedRoom = request.location[2]
        }
        
        loadBuildingsAndRooms(forCampus: selectedCampus ?? campus.first!)
    }

    // MARK: - Category
    private func fetchCategoriesAndSetupMenu() {
        db.collection("requests").document("001").getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                print("Error fetching document: \(error.localizedDescription)")
                return
            }

            guard let data = snapshot?.data() else {
                print("No data found in document")
                return
            }

            print("Document data: \(data)") // Print data to see if it's correct

            if let categories = data["category"] as? [String] {
                self.categories = categories
                self.prefillCategory()
                self.setupCategoryMenu()
            } else {
                print("No 'category' field in document")
            }
        }
    }


    private func prefillCategory() {
        guard let categoryName = currentRequest?.category.first,
              let index = categories.firstIndex(of: categoryName) else { return }
        selectedCategoryIndex = index
        categoryButton.setTitle(categoryName, for: .normal)
    }

    private func setupCategoryMenu() {
        let actions = categories.enumerated().map { (index, category) in
            UIAction(title: category) { [weak self] _ in
                self?.selectedCategoryIndex = index
                self?.categoryButton.setTitle(category, for: .normal)
            }
        }
        categoryButton.menu = UIMenu(title: "Select Category", children: actions)
        categoryButton.showsMenuAsPrimaryAction = true
    }

    // MARK: - Pickers
    private func setupPickers() {
        campusPickerView.delegate = self
        campusPickerView.dataSource = self
        buildingPickerView.delegate = self
        buildingPickerView.dataSource = self
        roomPickerView.delegate = self
        roomPickerView.dataSource = self
    }

    private func loadBuildingsAndRooms(forCampus campus: String) {
        guard let campusInfo = campusData[campus] else { return }
        building = campusInfo["buildings"] ?? []
        room = campusInfo["rooms"] ?? []

        if !building.contains(selectedBuilding ?? "") { selectedBuilding = building.first }
        if !room.contains(selectedRoom ?? "") { selectedRoom = room.first }

        buildingPickerView.reloadAllComponents()
        roomPickerView.reloadAllComponents()

        if let campusIndex = self.campus.firstIndex(of: campus) {
            campusPickerView.selectRow(campusIndex, inComponent: 0, animated: false)
        }
        if let buildingIndex = building.firstIndex(of: selectedBuilding ?? "") {
            buildingPickerView.selectRow(buildingIndex, inComponent: 0, animated: false)
        }
        if let roomIndex = room.firstIndex(of: selectedRoom ?? "") {
            roomPickerView.selectRow(roomIndex, inComponent: 0, animated: false)
        }
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        pickerView == campusPickerView ? campus.count :
        pickerView == buildingPickerView ? building.count : room.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        pickerView == campusPickerView ? campus[row] :
        pickerView == buildingPickerView ? building[row] : room[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == campusPickerView {
            selectedCampus = campus[row]
            loadBuildingsAndRooms(forCampus: selectedCampus!)
        } else if pickerView == buildingPickerView {
            selectedBuilding = building[row]
        } else {
            selectedRoom = room[row]
        }
    }

    // MARK: - Image
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
    }

    // MARK: - Image Download
    func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else { completion(nil); return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data, let image = UIImage(data: data) { completion(image) }
            else { completion(nil) }
        }.resume()
    }

    // MARK: - Cloudinary Upload
    private func uploadToCloudinary(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        AppDelegate.cloudinary.createUploader()
            .upload(data: data, uploadPreset: uploadPreset) { response, error in
                DispatchQueue.main.async {
                    if let error = error { completion(.failure(error)); return }
                    guard let url = response?.secureUrl else {
                        completion(.failure(NSError(domain: "", code: -1)))
                        return
                    }
                    completion(.success(url))
                }
            }
    }

    // MARK: - Submit
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        guard validateFields() else { return }

        if let image = selectedImage, image != imageView.image {
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

    private func performUpdate(imageUrl: String) {
        guard let selectedCategoryIndex = selectedCategoryIndex,
              let selectedCampus = selectedCampus,
              let selectedBuilding = selectedBuilding,
              let selectedRoom = selectedRoom
        else { return }
        
        let updateDTO = RequestUpdateDTO(
            title: titleTextField.text,
            description: descriptionTextField.text,
            location: [
                "campus": [selectedCampus],
                "building": [selectedBuilding],
                "room": [selectedRoom]
            ],
            categoryIndex: selectedCategoryIndex,
            priorityIndex: nil,
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
                guard let requestId = currentRequest?.id else { return }
                try await RequestManager.shared.updateRequest(
                    requestId: requestId,
                    updateDTO: updateDTO
                )
                showAlert("Request updated ✅")
            } catch {
                showAlert("Update failed ❌")
            }
        }
    }

    private func validateFields() -> Bool {
        guard
            let title = titleTextField.text, !title.isEmpty,
            let description = descriptionTextField.text, !description.isEmpty,
            selectedCategoryIndex != nil,
            selectedCampus != nil,
            selectedBuilding != nil,
            selectedRoom != nil
        else {
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

}
