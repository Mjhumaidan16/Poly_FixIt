import UIKit
import FirebaseFirestore
import FirebaseAuth

// Make userId accessible to all view controllers


final class PendingRequestsViewController: UIViewController {

    @IBOutlet weak var requestsStackView: UIStackView!
    @IBOutlet weak var refreshButton: UIButton!

    private let db = Firestore.firestore()
    private var renderToken = UUID()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("requestsStackView:", requestsStackView as Any)
        
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        loadPendingRequests()
    }

    @objc private func refreshTapped() {
        loadPendingRequests()
    }

    // MARK: - Load Requests
    private func loadPendingRequests() {
        let myToken = UUID()
        renderToken = myToken
        refreshButton.isEnabled = false

        guard let stackView = requestsStackView,
              let templateCard = stackView.arrangedSubviews.first(where: { $0.tag == 1 }) else {
            print("❌ Template card or stackView not found")
            refreshButton.isEnabled = true
            return
        }



        templateCard.isHidden = true

        // Clear previous cards
        print("StackView arrangedSubviews count:", requestsStackView.arrangedSubviews.count)
        for v in stackView.arrangedSubviews where v !== templateCard {
            print("Subview: \(v), tag: \(v.tag)")
            stackView.removeArrangedSubview(v)
            v.removeFromSuperview()
        }

        db.collection("requests")
            .whereField("status", isEqualTo: "pending")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                DispatchQueue.main.async { self.refreshButton.isEnabled = true }

                if let error = error {
                    print("❌ Firestore error:", error)
                    return
                }

                guard self.renderToken == myToken else { return }

                let docs = snapshot?.documents ?? []
                for (index, doc) in docs.enumerated() {
                    let data = doc.data()
                    let requestId = doc.documentID
                    let title = data["title"] as? String ?? "No Title"
                    let category = data["selectedCategory"] as? String ?? "No Category"
                    let locationArray = data["location"] as? [String] ?? ["Unknown", "Unknown", "Unknown"]
                    let location = "Campus: \(locationArray[0]), Building: \(locationArray[1]), Room: \(locationArray[2])"
                    let technician = data["assignedTechnician"] as? String ?? "Not Assigned"
                    let submittedBy = data["submittedBy"] as? String ?? "Unknown"
                    let date = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                    guard let card = templateCard.cloneView() else { continue }
                    card.isHidden = false
                    card.tag = 0

                    self.configureRequestCard(card,
                                              requestId: requestId,
                                              title: title,
                                              category: category,
                                              location: location,
                                              technician: technician,
                                              submittedBy: submittedBy,
                                              date: date,
                                              number: index + 1)

                    stackView.addArrangedSubview(card)
                }
            }
    }
    
    // MARK: - Find correct stack view dynamically
    private func findRequestsStackView() -> UIStackView? {
        return view.findSubview(ofType: UIStackView.self) { stack in
            stack.axis == .vertical &&
            stack.arrangedSubviews.contains(where: { $0.tag == 1 })
        }
    }


    // MARK: - Configure Card
    private func configureRequestCard(_ card: UIView,
                                      requestId: String,
                                      title: String,
                                      category: String,
                                      location: String,
                                      technician: String,
                                      submittedBy: String,
                                      date: Date,
                                      number: Int) {

        let labels = card.allSubviews.compactMap { $0 as? UILabel }
        let buttons = card.allSubviews.compactMap { $0 as? UIButton }

        // Labels
        let titleLabel = labels.first(where: { $0.text?.contains("Request:") ?? false })
        let categoryLabel = labels.first(where: { $0.text?.contains("Category:") ?? false })
        let locationLabel = labels.first(where: { $0.text?.contains("Location:") ?? false })
        let technicianLabel = labels.first(where: { $0.text?.contains("Technician:") ?? false })
        let submittedByLabel = labels.first(where: { $0.text?.contains("-") ?? false })

        titleLabel?.text = "Request: \(title)"
        categoryLabel?.text = "Category: \(category)"
        locationLabel?.text = location
        technicianLabel?.text = "Technician: \(technician)"
        submittedByLabel?.text = "\(submittedBy) - \(dateFormatter.string(from: date))"

        // Buttons
        if let acceptBtn = buttons.first(where: { $0.currentTitle?.lowercased() == "accept" }) {
            acceptBtn.accessibilityIdentifier = requestId
            acceptBtn.removeTarget(nil, action: nil, for: .allEvents)
            acceptBtn.addTarget(self, action: #selector(handleAcceptTapped(_:)), for: .touchUpInside)
        }

        if let cancelBtn = buttons.first(where: { $0.currentTitle?.lowercased() == "cancel" }) {
            cancelBtn.accessibilityIdentifier = requestId
            cancelBtn.removeTarget(nil, action: nil, for: .allEvents)
            cancelBtn.addTarget(self, action: #selector(handleCancelTapped(_:)), for: .touchUpInside)
        }

        if let editBtn = buttons.first(where: { $0.currentTitle?.lowercased() == "edit" }) {
            editBtn.accessibilityIdentifier = requestId
            editBtn.removeTarget(nil, action: nil, for: .allEvents)
            editBtn.addTarget(self, action: #selector(handleEditTapped(_:)), for: .touchUpInside)
        }
    }

    // MARK: - Button Actions
    @objc private func handleAcceptTapped(_ sender: UIButton) {
        guard let requestId = sender.accessibilityIdentifier else { return }
        updateRequestStatus(requestId: requestId, status: "Accepted")
    }

    @objc private func handleCancelTapped(_ sender: UIButton) {
        guard let requestId = sender.accessibilityIdentifier else { return }
        updateRequestStatus(requestId: requestId, status: "Canceled")
    }

    @objc private func handleEditTapped(_ sender: UIButton) {
        guard let requestId = sender.accessibilityIdentifier, !requestId.isEmpty else { return }

        let sb = self.storyboard ?? UIStoryboard(name: "Main", bundle: nil)
        guard let editVC = sb.instantiateViewController(
            withIdentifier: "EditRequestViewController"
        ) as? EditRequestViewController else {
            print("❌ Could not instantiate EditRequestViewController")
            return
        }

        editVC.userId = requestId   // ✅ BEST PRACTICE

        if let nav = self.navigationController {
            nav.pushViewController(editVC, animated: true)
        } else {
            editVC.modalPresentationStyle = .fullScreen
            present(editVC, animated: true)
        }
    }


    private func updateRequestStatus(requestId: String, status: String) {
        db.collection("requests").document(requestId).updateData(["status": status]) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert("Failed ❌: \(error.localizedDescription)")
                } else {
                    self?.showAlert("Request \(status) ✅")
                    self?.loadPendingRequests()
                }
            }
        }
    }

    // MARK: - Helpers
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Notice", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIView helpers
private extension UIView {
    func cloneView() -> UIView? {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: UIView.self, from: data)
        } catch {
            print("❌ Clone view failed:", error)
            return nil
        }
    }

    var allSubviews: [UIView] {
        subviews + subviews.flatMap { $0.allSubviews }
    }
}


// MARK: - UIView search helpers
extension UIView {
    func findSubview<T: UIView>(
        ofType type: T.Type,
        where predicate: ((T) -> Bool)? = nil
    ) -> T? {
        for subview in subviews {
            if let match = subview as? T,
               predicate?(match) ?? true {
                return match
            }
            if let found = subview.findSubview(ofType: type, where: predicate) {
                return found
            }
        }
        return nil
    }
}

