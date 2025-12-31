import UIKit
import FirebaseFirestore
import FirebaseAuth
import Cloudinary

private var selectedImage: UIImage?
private let uploadPreset = "iOS_requests_preset"

final class TechViewRequestViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionView: UITextView!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var priorityLevelLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var requesterLabel: UILabel!
    @IBOutlet weak var locationLabelw: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    

    @IBOutlet weak var BeginButton: UIButton!
    @IBOutlet weak var ChatButton: UIButton!

    // MARK: - Properties
    private let db = Firestore.firestore()
    private var currentRequest: Request?
    private var userNameCache: [String: String] = [:]
    
    /// MUST be set before presenting this VC
    var requestId: String?


    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        //precondition(requestId != nil, "❌ requestId was not set")
        descriptionView.isEditable = false
        descriptionView.isScrollEnabled = true

        guard let requestId, !requestId.isEmpty else {
            showAlert("Missing request id ❌")
            return
        }

        
        fetchRequest(requestId: requestId)
    }

    // MARK: - Fetch Request
    private func fetchRequest(requestId: String) {
        RequestManager.shared.fetchRequest(requestId: requestId) { [weak self] request in
            guard let self = self, let request = request else {
                self?.showAlert("Failed to load request ❌")
                return
            }
            self.currentRequest = request
            self.populateUI(with: request)
        }
    }


    // MARK: - Populate UI
    private func populateUI(with request: Request) {

        titleLabel.text = request.title
        descriptionView.text = request.description

        categoryLabel.text = request.selectedCategory ?? "-"
        priorityLevelLabel.text = "Priority: \(request.selectedPriorityLevel ?? "")"
        statusLabel.text = "Status:\(request.status)"

        // Location
        if request.location.count == 3 {
            locationLabelw.text = "\(request.location[0]) / \(request.location[1]) / \(request.location[2])"
        } else {
            locationLabelw.text = "-"
        }

        // Requester
        if let submittedBy = request.submittedBy {
            fetchRequesterName(from: submittedBy)
        } else {
            requesterLabel.text = "Unknown"
        }
        // Image
        if let imageUrl = request.imageUrl {
            downloadImage(from: imageUrl)
        } else {
            imageView.image = UIImage(named: "placeholder")
        }

        // Optional: hide buttons based on status
        ChatButton.isHidden = request.status == "begin"
    }
    
    private func fetchRequesterName(from ref: DocumentReference) {
        // Cache check (fast)
        if let cached = userNameCache[ref.documentID] {
            requesterLabel.text = cached
            return
        }

        ref.getDocument { [weak self] snap, error in
            guard let self else { return }

            if let error = error {
                print("❌ fetchRequesterName error:", error)
                DispatchQueue.main.async { self.requesterLabel.text = "Unknown" }
                return
            }

            let fullName = snap?.data()?["fullName"] as? String
            let nameToShow = (fullName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? fullName!
                : "Unknown"

            self.userNameCache[ref.documentID] = nameToShow

            DispatchQueue.main.async {
                self.requesterLabel.text = nameToShow
            }
        }
    }


    // MARK: - Button Actions

    @IBAction func BeginButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Begin Request",
            message: "Are you sure you want to begin this request?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "No", style: .cancel))

        alert.addAction(UIAlertAction(title: "Yes", style: .destructive) { [weak self] _ in
            guard let self = self else { return }

            self.updateRequestStatus("Begin") {
                self.navigateToBeginScreen()
            }
        })

        present(alert, animated: true)
    }

    private func navigateToBeginScreen() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "TechCompViewController")

        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
    }

/*
    @IBAction func chatButtonTapped(_ sender: UIButton) {
        guard let uid = sender.accessibilityIdentifier, !uid.isEmpty else { return }

        // Use the current storyboard when possible (safer than hardcoding "Main").
        let sb = self.storyboard ?? UIStoryboard(name: "Main", bundle: nil)
        guard let editVC = sb.instantiateViewController(withIdentifier: "ChatRequestViewController")
                as? ChatRequestViewController else {
            print("❌ Could not instantiate EditRequestViewController. Check Storyboard ID + Custom Class.")
            return
        }

        editVC.userId = uid

        // If this screen isn't embedded in a UINavigationController, push will do nothing.
        // Present modally as a fallback.
        if let nav = self.navigationController {
            nav.pushViewController(editVC, animated: true)
        } else {
            editVC.modalPresentationStyle = .fullScreen
            self.present(editVC, animated: true)
        }
    }
    */
    
    // MARK: - Firestore Helpers

    private func updateRequestStatus(_ status: String, completion: @escaping () -> Void) {
        guard let requestId = currentRequest?.id else { return }

        RequestManager.shared.updateRequestStatusOnly(
            requestId: requestId,
            status: status
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.statusLabel.text = "Status:\(status)"
                    completion()

                case .failure(let error):
                    self?.showAlert("Failed ❌: \(error.localizedDescription)")
                }
            }
        }
    }


    private func downloadImage(from urlString: String) {
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.imageView.image = image
            }
        }.resume()
    }

    // MARK: - Alert
    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Notice", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
