import UIKit
import FirebaseFirestore
import FirebaseAuth
import Cloudinary

private var selectedImage: UIImage?
private let uploadPreset = "iOS_requests_preset"

final class ViewRequestViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionView: UITextView!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var priorityLevelLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var requesterLabel: UILabel!
    @IBOutlet weak var locationLabelw: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var acceptButtonTapped: UIButton!
    @IBOutlet weak var reas_assignButton: UIButton!
    @IBOutlet weak var EditButton: UIButton!
    
    // MARK: - Properties
    private let db = Firestore.firestore()
    private var currentRequest: Request?
    private var userNameCache: [String: String] = [:]
    
    /// MUST be set before presenting this VC
    var requestId:String!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //precondition(requestId != nil, "❌ requestId was not set")
        descriptionView.isEditable = false
        descriptionView.isScrollEnabled = true
        
        fetchRequest()
    }
    
    // MARK: - Fetch Request
    private func fetchRequest() {
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
        priorityLevelLabel.text = request.selectedPriorityLevel ?? "-"
        statusLabel.text = request.status
        
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
        
        
        updateButtonStates(for: request.status)
        
        
    }
    
    
    private func updateButtonStates(for status: String) {

        let normalizedStatus = status.lowercased()

        // Edit & Reassign → only Pending
        EditButton.isEnabled = (normalizedStatus == "pending")
        
        reas_assignButton.isEnabled = (normalizedStatus != "pending")

        // Delete → disabled when completed
        deleteButton.isEnabled = (normalizedStatus != "completed")

        // Accept → enabled ONLY when pending
        acceptButtonTapped.isEnabled = (normalizedStatus == "pending")

        // Visual feedback
        styleButton(EditButton)
        styleButton(reas_assignButton)
        styleButton(deleteButton)
        styleButton(acceptButtonTapped)
    }

    
    private func styleButton(_ button: UIButton) {
        button.alpha = button.isEnabled ? 1.0 : 0.2
    }
    
    
    private func navigateToAdminTabBar() {
        let main = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "AdminTabBarViewController")

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let delegate = scene.delegate as? SceneDelegate,
           let window = delegate.window {
            window.rootViewController = main
            window.makeKeyAndVisible()
        } else {
            navigationController?.setViewControllers([main], animated: true)
        }
    }

    
    // MARK: - Button Actions
      @IBAction func deleteButtonTapped(_ sender: UIButton) {
          let alert = UIAlertController(
              title: "Cancel Request",
              message: "Are you sure you want to cancel this request?",
              preferredStyle: .alert
          )

          alert.addAction(UIAlertAction(title: "No", style: .cancel))
          alert.addAction(UIAlertAction(title: "Yes", style: .destructive) { [weak self] _ in
              self?.updateRequestStatus("Canceled")
              guard let self = self else { return }
              self.navigateToAdminTabBar()
          })

          present(alert, animated: true)
      }

      @IBAction func acceptButtonTapped(_ sender: UIButton) {
          let alert = UIAlertController(
              title: "Accept Request",
              message: "Accept this request?",
              preferredStyle: .alert
          )

          alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
          alert.addAction(UIAlertAction(title: "Accept", style: .default) { [weak self] _ in
              self?.updateRequestStatus("Accepted")
              guard let self = self else { return }
              self.navigateToAdminTabBar()
          })

          present(alert, animated: true)
      }
    
    @IBAction func editButtonTapped(_ sender: UIButton) {
        guard let uid = sender.accessibilityIdentifier, !uid.isEmpty else { return }
        
        // Use the current storyboard when possible (safer than hardcoding "Main").
        let sb = self.storyboard ?? UIStoryboard(name: "Main", bundle: nil)
        guard let editVC = sb.instantiateViewController(withIdentifier: "EditRequestViewController")
                as? EditRequestViewController else {
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
    
    @IBAction func assignButtonTapped(_ sender: UIButton) {
        guard let rid = self.requestId, !rid.isEmpty else { return }
        
        let sb = self.storyboard ?? UIStoryboard(name: "Main", bundle: nil)
        
        guard let vc = sb.instantiateViewController(withIdentifier: "AdminTechnicianReassignmentViewController")
                as? AdminTechnicianReassignmentViewController else {
            print("❌ Could not instantiate AdminTechnicianReassignmentViewController. Check Storyboard ID + Custom Class.")
            return
        }
        
        vc.requestID = rid
        
        if let nav = self.navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
    }
    
    
    // MARK: - Firestore Helpers
    
    private func updateRequestStatus(_ status: String) {
        guard let requestId = currentRequest?.id else { return }
        
        RequestManager.shared.updateRequestStatusOnly(
            requestId: requestId,
            status: status
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.statusLabel.text = status
                    self?.showAlert("Request updated to \(status) ✅")
                    
                case .failure(let error):
                    self?.showAlert("Failed ❌: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func fetchRequesterName(from ref: DocumentReference) {
        
        let uid = ref.documentID
        
        // Cache check (fast)
        if let cached = userNameCache[uid] {
            requesterLabel.text = cached
            return
        }
        
        db.collection("users").document(uid).getDocument { [weak self] snap, error in
            guard let self else { return }
            
            if let error = error {
                print("❌ fetchRequesterName(users/\(uid)) error:", error)
                DispatchQueue.main.async { self.requesterLabel.text = "Unknown" }
                return
            }
            
            let fullName = snap?.data()?["fullName"] as? String
            let nameToShow = (fullName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? fullName!
            : "Unknown"
            
            self.userNameCache[uid] = nameToShow
            
            DispatchQueue.main.async {
                self.requesterLabel.text = nameToShow
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


