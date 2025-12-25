import UIKit
import FirebaseFirestore
import FirebaseAuth

// Make userId accessible to all view controllers
var userId: String?

final class PendingRequestsViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var requestsStackView: UIStackView!
    @IBOutlet weak var refreshButton: UIButton!

    // MARK: - Properties
    private let db = Firestore.firestore()
    private var renderToken = UUID()

    override func viewDidLoad() {
        super.viewDidLoad()
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        loadPendingRequests()
    }

    // MARK: - Refresh
    @objc private func refreshTapped() {
        loadPendingRequests()
    }

    // MARK: - Load Requests
    private func loadPendingRequests() {
        let myToken = UUID()
        renderToken = myToken
        refreshButton.isEnabled = false

        // Prefer the tagged template card (tag == 1). If the tag wasn't set in Interface Builder,
        // fall back to the first arranged subview so the screen can still render.
        guard
            let stackView = requestsStackView,
            let templateCard = stackView.arrangedSubviews.first(where: { $0.tag == 1 })
                ?? stackView.arrangedSubviews.first
        else {
            print("❌ Template card or stackView not found")
            refreshButton.isEnabled = true
            return
        }


        templateCard.isHidden = true

        // Clear previous cards except template
        for v in stackView.arrangedSubviews where v !== templateCard {
            stackView.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        
        // ✅ Fetch ALL
        db.collection("requests")
            .whereField("status", isEqualTo: "Pending")
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
                    
                    let location = data["location"] as? [String: Any] ?? [:]
                    let campus = (location["campus"] as? [String])?.first ?? "Unknown"
                    let building = (location["building"] as? [String])?.first ?? "Unknown"
                    let room = (location["room"] as? [String])?.first ?? "Unknown"
                    let locationText = "\(campus), Building: \(building), Room: \(room)"


                    let technician = data["assignedTechnician"] as? String ?? "Not Assigned"
                    let submittedBy = data["submittedBy"] as? String ?? "Unknown"
                    let date = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    
                    print("RAW location:", data["location"] ?? "nil")


                    guard let card = templateCard.cloneView() else { continue }
                    print("🟢 CLONED CARD HIERARCHY START")
                    card.debugPrintHierarchy()
                    print("🟢 CLONED CARD HIERARCHY END")
                    card.isHidden = false
                    card.tag = 0

                    self.configureRequestCard(card,
                                              requestId: requestId,
                                              title: title,
                                              category: category,
                                              location: locationText,
                                              technician: technician,
                                              submittedBy: submittedBy,
                                              date: date,
                                              number: index + 1)

                    stackView.addArrangedSubview(card)
                }
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

        let labels = card.findRequestLabels()
        let buttons = card.findRequestButtons()


        // Labels
        labels.title?.text = "Request: \(title)"
        labels.category?.text = "Category: \(category)"
        labels.location?.text = location
        labels.technician?.text = "Technician: \(technician)"
        labels.submittedBy?.text = "\(submittedBy) - \(dateFormatter.string(from: date))"

        // Buttons
        if let detailsBtn = buttons.viewD {
            detailsBtn.accessibilityIdentifier = requestId
            detailsBtn.removeTarget(nil, action: nil, for: .allEvents)
            detailsBtn.addTarget(self, action: #selector(handleDetailsTapped(_:)), for: .touchUpInside)
        } else {
            print("❌ detailsBtn button not found in cloned card")
        }

        if let cancelBtn = buttons.cancel {
            cancelBtn.accessibilityIdentifier = requestId
            cancelBtn.removeTarget(nil, action: nil, for: .allEvents)
            cancelBtn.addTarget(self, action: #selector(handleCancelTapped(_:)), for: .touchUpInside)
        } else {
            print("❌ Cancel/Delete button not found in cloned card")
        }

        if let editBtn = buttons.edit {
            editBtn.accessibilityIdentifier = requestId
            editBtn.removeTarget(nil, action: nil, for: .allEvents)
            editBtn.addTarget(self, action: #selector(handleEditTapped(_:)), for: .touchUpInside)
        } else {
            print("❌ Edit button not found in cloned card")
        }
    }


    // MARK: - Button Actions
    @objc private func handleAcceptTapped(_ sender: UIButton) {
        guard let requestId = sender.accessibilityIdentifier else { return }
        updateRequestStatus(requestId: requestId, status: "Accepted")
        loadPendingRequests()
    }

    @objc private func handleCancelTapped(_ sender: UIButton) {
        guard let requestId = sender.accessibilityIdentifier else { return }
        updateRequestStatus(requestId: requestId, status: "Canceled")
        loadPendingRequests()
    }

    // Inside handleEditTapped:
    // ✅ NEW: Open edit screen + pass UID
        @objc private func handleEditTapped(_ sender: UIButton) {
            guard let uid = sender.accessibilityIdentifier, !uid.isEmpty else { return }

            // Use the current storyboard when possible (safer than hardcoding "Main").
            let sb = self.storyboard ?? UIStoryboard(name: "Main", bundle: nil)
            guard let editVC = sb.instantiateViewController(withIdentifier: "EditRequestViewController")
                    as? EditRequestViewController else {
                print("❌ Could not instantiate AdminEditTechnicianViewController. Check Storyboard ID + Custom Class.")
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
    
    
    // Inside handleDetailsTapped:
    // ✅ NEW: Open viwe Details screen + pass UID
        @objc private func handleDetailsTapped(_ sender: UIButton) {
            guard let uid = sender.accessibilityIdentifier, !uid.isEmpty else { return }

            // Use the current storyboard when possible (safer than hardcoding "Main").
            let sb = self.storyboard ?? UIStoryboard(name: "Main", bundle: nil)
            guard let editVC = sb.instantiateViewController(withIdentifier: "ViewRequestViewController")
                    as? ViewRequestViewController else {
                print("❌ Could not instantiate ViewRequestViewController. Check Storyboard ID + Custom Class.")
                return
            }

            editVC.requestId = uid

            // If this screen isn't embedded in a UINavigationController, push will do nothing.
            // Present modally as a fallback.
            if let nav = self.navigationController {
                nav.pushViewController(editVC, animated: true)
            } else {
                editVC.modalPresentationStyle = .fullScreen
                self.present(editVC, animated: true)
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

// MARK: - UIView Helpers
private extension UIView {
    
    func removeFixedWidthConstraints() {
        constraints
            .filter { $0.firstAttribute == .width && $0.relation == .equal }
            .forEach { $0.isActive = false }
        allSubviews.forEach { $0.removeFixedWidthConstraints() }
    }
    
        func cloneView() -> UIView? {
            do {
                let data = try NSKeyedArchiver.archivedData(
                    withRootObject: self,
                    requiringSecureCoding: false
                )

                let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
                unarchiver.requiresSecureCoding = false
                let view = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? UIView
                unarchiver.finishDecoding()

                return view
            } catch {
                print("❌ Clone view failed: \(error)")
                return nil
            }
        }



    var allSubviews: [UIView] {
        subviews + subviews.flatMap { $0.allSubviews }
    }
    
    func findSubview<T: UIView>(ofType: T.Type, where predicate: ((T) -> Bool)? = nil) -> T? {
        if let v = self as? T, predicate?(v) ?? true { return v }
        for sub in subviews {
            if let match: T = sub.findSubview(ofType: T.self, where: predicate) { return match }
        }
        return nil
    }
    

    func findLabel(named name: String) -> UILabel? {
        return allSubviews
            .compactMap { $0 as? UILabel }
            .first {
                $0.accessibilityIdentifier == name || $0.restorationIdentifier == name
            }
    }

    func findButton(named name: String) -> UIButton? {
        return allSubviews
            .compactMap { $0 as? UIButton }
            .first {
                $0.accessibilityIdentifier == name || $0.restorationIdentifier == name
            }
    }
    
    
    func debugPrintHierarchy(prefix: String = "") {
        let typeName = String(describing: type(of: self))
        let aid = accessibilityIdentifier ?? "nil"
        let rid = restorationIdentifier ?? "nil"

        print("\(prefix)↳ \(typeName) | accessibilityId: \(aid) | restorationId: \(rid)")

        subviews.forEach {
            $0.debugPrintHierarchy(prefix: prefix + "  ")
        }
    }
    
    
    func findRequestLabels() -> (title: UILabel?, category: UILabel?, location: UILabel?, technician: UILabel?, submittedBy: UILabel?) {
        let labels = allSubviews.compactMap { $0 as? UILabel }

        func byPrefix(_ prefix: String) -> UILabel? {
            labels.first { (($0.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)).hasPrefix(prefix) }
        }

        let title = byPrefix("Request:")
        let category = byPrefix("Category:")
        let location = byPrefix("Location:")
        let technician = byPrefix("Technician:")

        let submittedBy = labels.first {
            let t = ($0.text ?? "")
            return t.contains(" - ")
            && !t.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Request:")
            && !t.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Category:")
            && !t.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Location:")
            && !t.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Technician:")
        }

        return (title, category, location, technician, submittedBy)
    }

    func findRequestButtons() -> (viewD: UIButton?, edit: UIButton?, cancel: UIButton?) {
        let buttons = allSubviews.compactMap { $0 as? UIButton }

        func visibleTitle(_ b: UIButton) -> String {
            // Works for both old-style titles and UIButton.Configuration
            if let t = b.configuration?.title, !t.isEmpty { return t }
            if let t = b.title(for: .normal), !t.isEmpty { return t }
            if let t = b.titleLabel?.text, !t.isEmpty { return t }
            return ""
        }

        func byContains(_ needle: String) -> UIButton? {
            buttons.first {
                visibleTitle($0)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveContains(needle)
            }
        }

        // Use "contains" so spacing/case differences don’t break it
        let viewD = byContains("View Details")
        let edit = byContains("Edit")
        let cancel = byContains("Delete") ?? byContains("Cancel")

        return (viewD, edit, cancel)
    }




}
