import UIKit
import FirebaseFirestore

final class RateTechnicianViewController: UIViewController {

    // MARK: - Outlets (connect these correctly)
    // NOTE:
    // Your storyboard currently wires `ratingButton` to a UIMenu (not the UIButton),
    // which makes IBOutlet wiring unreliable and causes crashes.
    // To avoid editing the storyboard, ALL outlets are optional and we locate the
    // real dropdown UIButton at runtime.
    @IBOutlet weak var technicianNameLabel: UILabel?
    @IBOutlet weak var departmentLabel: UILabel?
    @IBOutlet weak var ticketTitleLabel: UILabel?

    // Keep this outlet optional and DO NOT rely on it.
    @IBOutlet weak var ratingButton: AnyObject?

    @IBOutlet weak var descriptionTextView: UITextView?

    // MARK: - Firestore
    private let db = Firestore.firestore()

    // For now you said this specific doc
    var requestId: String = "xnPtlNRUYzdPMB5GeXwf"

    // Dropdown options
    private let ratingOptions = ["Excellent", "Good", "Poor"]
    private var selectedRating: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Safe even if storyboard outlets are wrong.
        configureRatingMenu()
        fetchRequestAndPopulateUI()
    }

    // MARK: - Menu (Dropdown)
    private func configureRatingMenu() {
        guard let button = resolveRatingDropdownButton() else {
            // Don't crash; just log so you can see what's missing.
            print("⚠️ Could not find rating dropdown UIButton in the view hierarchy.")
            return
        }

        guard #available(iOS 14.0, *) else {
            button.isEnabled = false
            button.setTitle("iOS 14+ required", for: .normal)
            return
        }

        let actions = ratingOptions.map { option in
            UIAction(title: option) { [weak self] _ in
                guard let self else { return }
                self.selectedRating = option
                // show selection on the real dropdown button
                self.resolveRatingDropdownButton()?.setTitle(option, for: .normal)
            }
        }

        button.menu = UIMenu(title: "Select Rating", children: actions)
        button.showsMenuAsPrimaryAction = true

        // default title
        if button.title(for: .normal)?.isEmpty != false {
            button.setTitle("Select Rating", for: .normal)
        }
    }

    /// Finds the real dropdown UIButton without relying on broken storyboard outlets.
    /// In your storyboard the dropdown button title/config is "ValidityDropButton".
    private func resolveRatingDropdownButton() -> UIButton? {
        // Prefer: find by title used in storyboard
        if let byTitle = findFirstButton(in: view, whereTitleIs: "ValidityDropButton") {
            return byTitle
        }

        // Fallback: any button that already has a menu (iOS 14+)
        if #available(iOS 14.0, *) {
            if let byMenu = findFirstButtonWithMenu(in: view) {
                return byMenu
            }
        }
        return nil
    }

    private func findFirstButton(in root: UIView?, whereTitleIs title: String) -> UIButton? {
        guard let root else { return nil }
        for sub in root.subviews {
            if let btn = sub as? UIButton {
                if btn.currentTitle == title { return btn }
                // also check configuration title (iOS 15+)
                if btn.configuration?.title == title { return btn }
            }
            if let found = findFirstButton(in: sub, whereTitleIs: title) { return found }
        }
        return nil
    }

    @available(iOS 14.0, *)
    private func findFirstButtonWithMenu(in root: UIView?) -> UIButton? {
        guard let root else { return nil }
        for sub in root.subviews {
            if let btn = sub as? UIButton, btn.menu != nil {
                return btn
            }
            if let found = findFirstButtonWithMenu(in: sub) { return found }
        }
        return nil
    }

    // MARK: - Fetch request -> fetch technician -> update UI
    private func fetchRequestAndPopulateUI() {
        let requestRef = db.collection("requests").document(requestId)

        requestRef.getDocument { [weak self] snap, err in
            guard let self else { return }
            if let err = err {
                print("❌ Request fetch error:", err)
                self.showAlert(title: "Error", message: "Could not load the ticket.")
                return
            }
            guard let data = snap?.data() else {
                self.showAlert(title: "Error", message: "Ticket not found.")
                return
            }

            // Title label
            let title = data["title"] as? String ?? ""
            self.ticketTitleLabel?.text = title

            // Prefill existing rate if any
            if let rate = data["rate"] as? [String: Any] {
                let existingRating = (rate["rating"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let existingDesc = rate["description"] as? String ?? ""

                if !existingRating.isEmpty {
                    self.selectedRating = existingRating
                    self.resolveRatingDropdownButton()?.setTitle(existingRating, for: .normal)
                }

                if !existingDesc.isEmpty {
                    self.descriptionTextView?.text = existingDesc
                }
            }

            // Technician reference
            guard let techRef = data["assignedTechnician"] as? DocumentReference else {
                self.technicianNameLabel?.text = "No technician assigned"
                self.departmentLabel?.text = "Department: -"
                return
            }

            techRef.getDocument { [weak self] techSnap, techErr in
                guard let self else { return }
                if let techErr = techErr {
                    print("❌ Tech fetch error:", techErr)
                    self.technicianNameLabel?.text = "Unknown"
                    self.departmentLabel?.text = "Department: -"
                    return
                }
                guard let techData = techSnap?.data() else {
                    self.technicianNameLabel?.text = "Unknown"
                    self.departmentLabel?.text = "Department: -"
                    return
                }

                let fullName = techData["fullName"] as? String ?? "Unknown"
                let dept = techData["Department"] as? String ?? "-"

                self.technicianNameLabel?.text = fullName
                self.departmentLabel?.text = "Dep: \(dept)"
            }
        }
    }

    // MARK: - Submit (Confirm button)
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        saveRatingToRequest()
    }

    private func saveRatingToRequest() {
        let desc = (descriptionTextView?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard let rating = selectedRating, ratingOptions.contains(rating) else {
            showAlert(title: "Missing Rating", message: "Please choose: Excellent, Good, or Poor.")
            return
        }

        db.collection("requests").document(requestId).updateData([
            "rate": [
                "rating": rating,
                "description": desc
            ],
            "updatedAt": FieldValue.serverTimestamp()
        ]) { [weak self] err in
            guard let self else { return }
            if let err = err {
                print("❌ Save rating error:", err)
                self.showAlert(title: "Error", message: "Could not save your rating.")
                return
            }
            self.showAlert(title: "Saved", message: "Thank you for your feedback!")
        }
    }

    // MARK: - Alert
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
