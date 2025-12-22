import UIKit
import FirebaseFirestore
import FirebaseAuth
import Cloudinary


final class EditInventoryViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var itemNameTextField: UITextField!
    @IBOutlet weak var itemIdTextField: UITextField!
    @IBOutlet weak var categoryButton: UIButton!
    @IBOutlet weak var minimumThresholdTextField: UITextField!
    @IBOutlet weak var quantityAvailableTextField: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    
    var inventoryId: String!
    private var inventory: Inventory?
    private var selectedCategory: String?
    private var selectedImage: UIImage?
    private let uploadPreset = "iOS_inventory_preset"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        fetchInventory()
        setupImageTap()
    }
    
    private func fetchInventory() {
        InventoryManager.shared.fetchInventory(inventoryId: inventoryId) { [weak self] inv in
            guard let self = self, let inv = inv else { return }
            self.inventory = inv
            self.prefillFields()
        }
    }
    
    private func prefillFields() {
        guard let inventory = inventory else { return }
        itemNameTextField.text = inventory.itemName
        itemIdTextField.text = inventory.itemId
        selectedCategory = inventory.selectedCategory
        minimumThresholdTextField.text = "\(inventory.minimumThreshold)"
        quantityAvailableTextField.text = "\(inventory.quantityAvailable)"
        
        if let imageUrl = inventory.imageUrl {
            downloadImage(from: imageUrl) { [weak self] image in
                DispatchQueue.main.async { self?.imageView.image = image }
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
        guard let inventory = inventory else { return }
        if let image = selectedImage {
            uploadToCloudinary(image: image) { [weak self] result in
                switch result {
                case .success(let url): self?.performUpdate(imageUrl: url)
                case .failure: self?.showAlert("Image upload failed ❌")
                }
            }
        } else {
            performUpdate(imageUrl: inventory.imageUrl ?? "")
        }
    }
    
    private func performUpdate(imageUrl: String) {
        let updateDTO = InventoryUpdateDTO(
            itemName: itemNameTextField.text,
            category: inventory?.category,
            selectedCategory: selectedCategory,
            imageUrl: imageUrl,
            quantityAvailable: Int(quantityAvailableTextField.text ?? ""),
            minimumThreshold: Int(minimumThresholdTextField.text ?? ""),
            usageHistory: inventory?.usageHistory
        )
        Task {
            do {
                try await InventoryManager.shared.updateInventory(inventoryId: inventoryId, updateDTO: updateDTO)
                showAlert("Inventory updated ✅")
            } catch {
                showAlert("Failed to update inventory: \(error)")
            }
        }
    }
    
    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        InventoryManager.shared.deleteInventory(inventoryId: inventoryId) { [weak self] result in
            switch result {
            case .success:
                self?.showAlert("Inventory deleted ✅")
                self?.navigationController?.popViewController(animated: true)
            case .failure(let error):
                self?.showAlert("Delete failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func uploadToCloudinary(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        AppDelegate.cloudinary.createUploader().upload(data: data, uploadPreset: uploadPreset) { response, error in
            if let error = error { completion(.failure(error)); return }
            guard let url = response?.secureUrl else { completion(.failure(NSError(domain: "", code: -1))); return }
            completion(.success(url))
        }
    }
    
    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Notice", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else { completion(nil); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data, let image = UIImage(data: data) { completion(image) }
            else { completion(nil) }
        }.resume()
    }
}
