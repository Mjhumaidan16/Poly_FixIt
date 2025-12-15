import UIKit
import FirebaseFirestore
import FirebaseAuth

final class RequestViewController2: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    // MARK: - IBOutlets
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var descriptionTextField: UITextField!
    @IBOutlet weak var categoryButton: UIButton!
    @IBOutlet weak var campusPickerView: UIPickerView!
    @IBOutlet weak var buildingPickerView: UIPickerView!
    @IBOutlet weak var roomPickerView: UIPickerView!
    @IBOutlet weak var submitButton: UIButton!

    // MARK: - Properties
    private let db = Firestore.firestore()
    
    private var categories: [String] = []
    private var campus: [String] = []
    private var building: [String] = []
    private var room: [String] = []
    
    private var selectedCategoryIndex: Int?
    private var selectedCategoryName: String?
    private var selectedCampus: String?
    private var selectedBuilding: String?
    private var selectedRoom: String?

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
        
        // Initialize default selections (optional)
        selectedCampus = campus.first
        selectedBuilding = building.first // Default building, for example
        selectedRoom = room.first // Default room, for example

        // Reload pickers initially
        campusPickerView.reloadAllComponents()
        buildingPickerView.reloadAllComponents()
        roomPickerView.reloadAllComponents()
        
        // Fetch location data and shared settings
        fetchLocations()
        fetchSharedSettings() // Fetch shared settings from the "requests/001" document
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
            
            // Safely access the 'location' dictionary and fetch campuses, buildings, and rooms
                    if let location = data["location"] as? [String: Any] {
                        // Fetch campuses
                        if let campuses = location["campus"] as? [String] {
                            self.campus = campuses
                        } else {
                            print("Campuses not found in 'requests/001'.")
                        }

                        // Fetch buildings
                        if let buildings = location["building"] as? [String] {
                            self.building = buildings
                            print(buildings)
                        } else {
                            print("Buildings not found in 'requests/001'.")
                        }

                        // Fetch rooms
                        if let rooms = location["room"] as? [String] {
                            self.room = rooms
                            print(rooms)
                        } else {
                            print("Rooms not found in 'requests/001'.")
                        }
                    } else {
                        print("Location data is missing or incorrectly formatted.")
                    }


            // Reload the pickers with the fetched data
            DispatchQueue.main.async {
                // Print the data to confirm everything is loaded
                 print("Campuses: \(self.campus)")
                 print("Buildings: \(self.building)")
                 print("Rooms: \(self.room)")
                
                self.campusPickerView.reloadAllComponents()
                self.buildingPickerView.reloadAllComponents()
                self.roomPickerView.reloadAllComponents()
                self.setupCategoryMenu() // Setup category button after loading categories
            }
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
            print("Selected Campus:",selectedCampus)  // Debugging
            fetchBuildings(forCampus: selectedCampus!)
        } else if pickerView == buildingPickerView {
            selectedBuilding = building[row]
            print("Selected Building: \(selectedBuilding)")  // Debugging
            fetchRooms(forBuilding: selectedBuilding!)
        } else if pickerView == roomPickerView {
            selectedRoom = room[row]
            print("Selected Room: \(selectedRoom)")  // Debugging
        }
    }


    // MARK: - Submit Action
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        guard validateFields() else { return }

        guard let currentUser = Auth.auth().currentUser else {
            showAlert("You must be signed in.")
            return
        }

        // Ensure the category index and campus are selected
        guard let selectedCategoryIndex = selectedCategoryIndex,
              let selectedCampus = selectedCampus,
              let selectedBuilding = selectedBuilding,
              let selectedRoom = selectedRoom else {
            showAlert("Please select both category and campus.")
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
            submittedBy: db.collection("users").document(currentUser.uid) // Use current user's UID
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

    // MARK: - Location Setup
    private func fetchLocations() {
        db.collection("settings").document("location").getDocument { snapshot, error in
            if let error = error {
                print("Location fetch error:", error)
                return
            }

            guard let data = snapshot?.data(),
                  let campuses = data["campus"] as? [String] else {
                // Fallback if campus data is missing
                print("No location data found for campus. Using default campus.")
                self.selectedCampus = self.campus.first
                DispatchQueue.main.async {
                    self.campusPickerView.reloadAllComponents()
                }
                return
            }
            self.campus = campuses
            self.selectedCampus = self.campus.first

            DispatchQueue.main.async {
                self.campusPickerView.reloadAllComponents()
            }

            // Fetch buildings for the selected campus
            self.fetchBuildings(forCampus: self.selectedCampus!)
        }
    }

    func fetchBuildings(forCampus campus: String) {
        db.collection("settings").document("location")
            .collection(campus).document("building")
            .getDocument { snapshot, error in
                if let error = error {
                    print("Building fetch error:", error)
                    return
                }

                guard let data = snapshot?.data(),
                      let buildings = data["building"] as? [String] else {
                    // Fallback if building data is missing
                    print("No building data found for \(campus). Using default building.")
                    self.selectedBuilding = self.building.first

                    DispatchQueue.main.async {
                        self.buildingPickerView.reloadAllComponents()
                        self.fetchRooms(forBuilding: self.selectedBuilding!)
                    }
                    return
                }

                self.building = buildings
                self.selectedBuilding = self.building.first

                DispatchQueue.main.async {
                    self.buildingPickerView.reloadAllComponents()
                    self.fetchRooms(forBuilding: self.selectedBuilding!)
                }
            }
    }

    func fetchRooms(forBuilding building: String) {
        db.collection("settings").document("location")
            .collection(selectedCampus!).document(building)
            .getDocument { snapshot, error in
                if let error = error {
                    print("Room fetch error:", error)
                    return
                }

                guard let data = snapshot?.data(),
                      let rooms = data["room"] as? [String] else {
                    // Fallback if room data is missing
                    print("No room data found for \(building). Using default room.")
                    self.selectedRoom = self.room.first

                    DispatchQueue.main.async {
                        self.roomPickerView.reloadAllComponents()
                    }
                    return
                }

                self.room = rooms
                self.selectedRoom = self.room.first

                DispatchQueue.main.async {
                    self.roomPickerView.reloadAllComponents()
                }
            }
    }

    // MARK: - Helpers
    private func validateFields() -> Bool {
        guard
            let title = titleTextField.text, !title.isEmpty,
            let description = descriptionTextField.text, !description.isEmpty,
            selectedCategoryIndex != nil,  // Validate category index
            selectedCampus != nil
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
