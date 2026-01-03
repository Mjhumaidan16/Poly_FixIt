import UIKit
import FirebaseFirestore
import FirebaseAuth
import Cloudinary

final class TechCompViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var descriptionView: UITextView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var submitButton: UIButton!
    
    // MARK: - Config
    private let uploadPreset = "iOS_requests_preset"
    private let defaultImageUrl = "https://res.cloudinary.com/polyfixit/image/upload/v1766424070/images-3_ufcbkf.png"
    
    //  Destination storyboard ID
    private let nextViewControllerID = "TechnicianHomeViewController"
    
    // MARK: - State
    private var selectedImage: UIImage?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Tap to pick image
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageViewTapped))
        imageView.addGestureRecognizer(tapGesture)
        imageView.isUserInteractionEnabled = true
        imageView.clipsToBounds = true
        
        //  Set default image from Cloudinary
        downloadImage(from: defaultImageUrl) { [weak self] image in
            DispatchQueue.main.async {
                self?.imageView.image = image
                self?.imageView.contentMode = .scaleAspectFit
            }
        }
        
        // Submit
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func submitTapped() {
        let notes = (descriptionView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !notes.isEmpty else {
            showAlert(title: "Missing Info", message: "Please add completion notes.")
            return
        }
        
        // If user selected an image -> upload it, else use default URL
        if let picked = selectedImage {
            uploadToCloudinary(image: picked) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let uploadedUrl):
                    //  Use notes + uploadedUrl in Firestore update if needed
                    self.showSuccessThenNavigate()
                case .failure:
                    self.showAlert(title: "Upload Failed", message: "Could not upload image. Please try again.")
                }
            }
        } else {
            //  Use notes + defaultImageUrl in Firestore update if needed
            showSuccessThenNavigate()
        }
    }
    
    private func showSuccessThenNavigate() {
        let alert = UIAlertController(title: "Saved", message: "Thank you for your feedback!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.navigateNext()
        })
        present(alert, animated: true)
    }
    
    private func navigateNext() {
        let vc = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: nextViewControllerID)
        
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
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
    
    // MARK: - Upload to Cloudinary (unsigned preset)
    private func uploadToCloudinary(
        image: UIImage,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "image", code: -1)))
            return
        }
        
        AppDelegate.cloudinary.createUploader()
            .upload(data: data, uploadPreset: uploadPreset, completionHandler: { response, error in
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
            }
    )}

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

    // MARK: - Alert
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

//  Put delegate methods in an extension + mark them @objc
extension TechCompViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @objc func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
    ) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage else { return }
        imageView.image = image
        imageView.contentMode = .scaleAspectFill
        selectedImage = image
    }

    @objc func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
