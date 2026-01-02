import UIKit
import FirebaseFirestore
import FirebaseAuth
import Cloudinary

private var selectedImage: UIImage?
private let uploadPreset = "iOS_requests_preset"

final class EditRequestViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var descriptionTextView: UITextView!
    @IBOutlet weak var categoryButton: UIButton!
    @IBOutlet weak var locationPickerView: UIPickerView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var deleteButton: UIButton! //new delete button
    @IBOutlet weak var submitButton: UIButton!

    // MARK: - Properties
    private let db = Firestore.firestore()
    private var uploadedImageUrl: String?
     var currentRequest: Request?
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
    private var campus: [String] = []
    private var building: [String] = []
    private var room: [String] = []

    private var selectedCategory: String?
    private var selectedCampus: String?
    private var selectedBuilding: String?
    private var selectedRoom: String?

     var userId: String = ""

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad called")
        
        // Ensure IBOutlets are connected
        // This will crash early (and clearly) if storyboard outlets are miswired.
        precondition(titleTextField != nil, "titleTextField outlet is not connected")
        precondition(descriptionTextView != nil, "descriptionTextField outlet is not connected")
        //precondition(categoryButton != nil, "categoryButton outlet is not connected")
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
                // Populate the available categories from the fetched document.
                self.categories = request.category
                // Set selected category (if stored) so validation passes without forcing a re-pick.
                self.selectedCategory = request.selectedCategory
                self.prefillFields(with: request)
                self.enableEditing()
                print("Fetched categories:", self.categories)
            } else {
                print("Failed to fetch request.")
            }
        }
    }
    
    
       private func setupCategoryMenu() {
           // Ensure categories is not empty before setting up the menu
           guard !categories.isEmpty else {
               print("No categories available to setup menu.")
               return
           }

           print("Categories available: \(categories)")

           // If nothing is selected yet, default to the first option so validation passes.
           if selectedCategory == nil {
               selectedCategory = categories.first
               if let selectedCategory { categoryButton.setTitle(selectedCategory, for: .normal) }
           }

           // Creating actions for each category
           let actions = categories.map { (category) in
               print("Creating action for category: \(category)")

               return UIAction(title: category) { [weak self] _ in
                   self?.selectedCategory = category  // Set selectedCategory to category
                   self?.categoryButton.setTitle(category, for: .normal)
                   print("Category selected: \(self?.selectedCategory ?? "None")")
               }
           }

           categoryButton.menu = UIMenu(title: "Select Category", children: actions)
           categoryButton.showsMenuAsPrimaryAction = true
           print("Menu assigned to categoryButton.")
       }

    // MARK: - Enable/Disable Editing
    private func enableEditing() {
        titleTextField.isEnabled = true
        categoryButton.isEnabled = true
        locationPickerView.isUserInteractionEnabled = true
        submitButton.isEnabled = true
    }

    private func disableEditing() {
        titleTextField.isEnabled = false
        //descriptionTextField.isEnabled = false
        categoryButton.isEnabled = false
        locationPickerView.isUserInteractionEnabled = false
        submitButton.isEnabled = false
    }

    // MARK: - Prefill Fields
    private func prefillFields(with request: Request) {
        titleTextField.text = request.title
        descriptionTextView.text = request.description

        if let selected = request.selectedCategory, !selected.isEmpty {
            selectedCategory = selected
            categoryButton.setTitle(selected, for: .normal)
        }

        if let imageUrl = request.imageUrl {
            uploadedImageUrl = imageUrl
            downloadImage(from: imageUrl) { image in
                DispatchQueue.main.async { self.imageView.image = image }
            }
            print("Downloading image from URL: \(imageUrl)")

        }

        guard request.location.count == 3 else {
            print(" Invalid location array, skipping location prefill")
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

        locationPickerView.reloadAllComponents()

        if let campusIndex = campus.firstIndex(of: campusValue) {
            locationPickerView.selectRow(campusIndex, inComponent: 0, animated: false)
        }
        if let buildingIndex = building.firstIndex(of: buildingValue) {
            locationPickerView.selectRow(buildingIndex, inComponent: 1, animated: false)
        }
        if let roomIndex = room.firstIndex(of: roomValue) {
            locationPickerView.selectRow(roomIndex, inComponent: 2, animated: false)
        }
        
        setupCategoryMenu()
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
          didPickNewImage = true
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
    
    // MARK: - delete
    private func deleteRequestFromManager() {
        let requestId = userId
        
        RequestManager.shared.deleteRequest(requestId: requestId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    //self?.showAlert("Request deleted successfully ")
                    self?.navigationController?.popViewController(animated: true)
                    (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.window?.rootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "UserTabController")
                case .failure(let error):
                    self?.showAlert("Failed to delete request : \(error.localizedDescription)")
                }
            }
        }
    }
    
    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Delete Request",
            message: "Are you sure you want to delete this request? This action cannot be undone.",
            preferredStyle: .alert
        )
        
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
                case .failure: self?.showAlert("Image upload failed ")
                }
            }
        } else {
            performUpdate(imageUrl: uploadedImageUrl ?? "")
        }
    }
    
    private func validateFields() -> Bool {
        guard let title = titleTextField.text, !title.isEmpty,
              let description = descriptionTextView.text, !description.isEmpty,
              selectedCategory != nil,
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
              let selectedCampus = selectedCampus,
              let selectedBuilding = selectedBuilding,
              let selectedRoom = selectedRoom else { return }

        let updateDTO = RequestUpdateDTO(
            title: titleTextField.text,
            description: descriptionTextView.text,
            location: ["campus": [selectedCampus],
                       "building": [selectedBuilding],
                       "room": [selectedRoom]],
            // Keep the categories list from the fetched document (or fallback to current list)
            category: (currentRequest?.category.isEmpty == false ? currentRequest!.category : categories),
            priorityLevel: currentRequest?.priorityLevel ?? ["high","medium","low"],
            selectedCategory: selectedCategory,
            selectedPriorityLevel: currentRequest?.selectedPriorityLevel ?? "low",
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
                //showAlert("Request submitted successfully ")
                (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.window?.rootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "UserTabController")
            } catch {
                showAlert("Failed to submit request ")
            }
        }
    }
}
