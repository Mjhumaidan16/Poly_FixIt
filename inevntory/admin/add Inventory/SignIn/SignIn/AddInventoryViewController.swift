import UIKit
import FirebaseFirestore
import FirebaseAuth
import Cloudinary

private var selectedImage: UIImage?
private let uploadPreset = "iOS_requests_preset"

final class AddInventoryViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var itemNameTextField: UITextField!
    @IBOutlet weak var itemIdTextField: UITextField!
    @IBOutlet weak var categoryButton: UIButton!
    @IBOutlet weak var minimumThresholdTextField: UITextField!
    @IBOutlet weak var quantityAvailableTextField: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var submitButton: UIButton!
    
    private var selectedCategory: String?
    private var categories: [String] = []
    private var selectedImage: UIImage?
    private let uploadPreset = "iOS_inventory_preset"
    
    private let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupImageTap()
        
        fetchSharedSettings() // Fetch shared settings from the "requests/001" document
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
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
    
    // MARK: - Fetch Shared Settings (from "requests/001" document)
    func fetchSharedSettings() {
        db.collection("Inventory").document("001").getDocument { snapshot, error in
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
        
        // ✅ Set default image from Cloudinary
            let defaultImageUrl = "https://res.cloudinary.com/polyfixit/image/upload/v1766424070/images-3_ufcbkf.png"
            downloadImage(from: defaultImageUrl) { [weak self] image in
                DispatchQueue.main.async {
                    self?.imageView.image = image
                    self?.imageView.contentMode = .scaleAspectFit
                }
            }
    }
    
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
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        selectedImage = info[.originalImage] as? UIImage
        imageView.image = selectedImage
    }
    
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        guard
            let itemName = itemNameTextField.text, !itemName.isEmpty,
            let itemId = itemIdTextField.text, !itemId.isEmpty,
            let selectedCategory,
            let minimumThreshold = Int(minimumThresholdTextField.text ?? ""),
            let quantityAvailable = Int(quantityAvailableTextField.text ?? "")
        else {
            showAlert("Please fill all fields correctly")
            return
        }
        
        guard let image = selectedImage else {
            showAlert("Please select an image")
            return
        }
        
        uploadToCloudinary(image: image) { [weak self] result in
            switch result {
            case .success(let url):
                let inventory = InventoryCreateDTO(
                    itemId: itemId,
                    itemName: itemName,
                    category: self?.categories ?? [],
                    selectedCategory: selectedCategory,
                    imageUrl: url,
                    quantityAvailable: quantityAvailable,
                    minimumThreshold: minimumThreshold,
                    usageHistory: [],
                    createdAt: Timestamp()
                )
                
                Task {
                    do {
                        let id = try await InventoryManager.shared.addInventory(inventory)
                        self?.showAlert("Inventory added! ID: \(id)")
                    } catch {
                        self?.showAlert("Failed to add inventory: \(error)")
                    }
                }
            case .failure(let error):
                self?.showAlert("Image upload failed: \(error.localizedDescription)")
            }
        }
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
        AppDelegate.cloudinary.createUploader().upload(data: data, uploadPreset: uploadPreset, completionHandler: { response, error in
            if let error = error { completion(.failure(error)); return }
            guard let url = response?.secureUrl else { completion(.failure(NSError(domain: "", code: -1))); return }
            completion(.success(url))
        })
    }
    
    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Notice", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
