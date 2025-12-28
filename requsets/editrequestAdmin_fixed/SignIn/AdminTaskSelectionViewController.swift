import UIKit
import FirebaseFirestore

final class AdminTaskSelectionViewController: UIViewController {

    // MARK: - Passed in (from TechListViewController)
    var technicianUID: String!

    // MARK: - Firestore
    private let db = Firestore.firestore()

    // MARK: - UI Outlets (connect if you want, but code can also auto-find)
    @IBOutlet  var tasksStackView: UIStackView?
    @IBOutlet  var searchBar: UISearchBar?
    @IBOutlet var confirmButton: UIButton?

    // MARK: - Internal state
    private var allRequests: [RequestItem] = []
    private var filteredRequests: [RequestItem] = []
    private var selectedRequestIDs = Set<String>()   // max 3
    private var renderToken = UUID()

    // Template card (first arrangedSubview in storyboard stack)
    @IBOutlet var templateCardView: UIView?

    // MARK: - Models
    private struct RequestItem {
        let id: String
        let title: String
        let description: String
        let priority: String
        let createdAt: Date?
        let locationText: String
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Safety
        if technicianUID == nil || technicianUID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("❌ technicianUID is missing. Make sure you pass it before presenting this VC.")
        }

        wireUpUI()
        loadAndRender()
    }

    // MARK: - UI Setup
    private func wireUpUI() {
        // Search bar
        if searchBar == nil {
            searchBar = findSearchBar(in: view)
        }
        searchBar?.delegate = self
        searchBar?.autocapitalizationType = .none

        // Confirm button
        if confirmButton == nil {
            confirmButton = findButton(withTitleContains: "Confirm", in: view)
        }
        confirmButton?.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)

        // Stack view
        if tasksStackView == nil {
            tasksStackView = findFirstStackView(in: view)
        }

        // Template card
        if let stack = tasksStackView {
            // We assume the storyboard already contains at least 1 sample card view inside stack view
            templateCardView = stack.arrangedSubviews.first
            templateCardView?.isHidden = true
        }
    }

    // MARK: - Data Load
    func loadAndRender() {
        let myToken = UUID()
        renderToken = myToken

        guard let techUID = technicianUID, !techUID.isEmpty else { return }

        // Requests that are "accepted" but not assigned
        // assignedTechnician == null
        let q = db.collection("requests")
            .whereField("status", isEqualTo: "accepted")
            .whereField("assignedTechnician", isEqualTo: NSNull())

        q.getDocuments { [weak self] snap, err in
            guard let self else { return }
            guard self.renderToken == myToken else { return }

            if let err = err {
                print("❌ Failed to fetch requests: \(err)")
                self.showAlert(title: "Error", message: "Failed to fetch requests.")
                return
            }

            let docs = snap?.documents ?? []
            self.allRequests = docs.map { doc in
                let data = doc.data()

                let title = (data["title"] as? String) ?? "#\(doc.documentID)"
                let desc = (data["description"] as? String) ?? ""

                // Try to build a readable location string from your map structure
                let locationText = self.buildLocationText(from: data["location"] as? [String: Any])

                let priority = (data["selectedPriorityLevel"] as? String)
                    ?? ((data["priorityLevel"] as? [String])?.first ?? "—")

                let createdAt: Date?
                if let ts = data["createdAt"] as? Timestamp {
                    createdAt = ts.dateValue()
                } else {
                    createdAt = nil
                }

                return RequestItem(
                    id: doc.documentID,
                    title: title,
                    description: desc,
                    priority: priority,
                    createdAt: createdAt,
                    locationText: locationText
                )
            }

            self.filteredRequests = self.allRequests
            self.selectedRequestIDs.removeAll()
            self.renderList()
        }
    }

    // MARK: - Render
    private func renderList() {
        guard let stack = tasksStackView else { return }

        // Clear generated cards (keep template only)
        for v in stack.arrangedSubviews {
            if v === templateCardView { continue }
            stack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }

        guard let template = templateCardView else {
            print("❌ No template card found in stack view. Add 1 sample card view inside the stack in storyboard.")
            return
        }

        for item in filteredRequests {
            let card = cloneTemplateCard(template)
            configure(card: card, item: item)
            stack.addArrangedSubview(card)
        }
    }

    private func configure(card: UIView, item: RequestItem) {
        // We expect labels + a switch inside each card (like your storyboard sample)
        let labels = findLabels(in: card)
        let sw = findSwitch(in: card)

        // Your storyboard sample has 4 labels:
        // - big title (#T-121 : Poor Wifi)
        // - location
        // - priority
        // - created date
        // We'll map by "best guess" based on font size (largest = title)
        let sortedByFont = labels.sorted { ($0.font.pointSize) > ($1.font.pointSize) }
        let titleLabel = sortedByFont.first
        let other = Array(sortedByFont.dropFirst())

        titleLabel?.text = item.title.isEmpty ? "#\(item.id)" : item.title

        // Fill the remaining labels with location / priority / created
        // (Order doesn’t need to be perfect; it just needs to show correctly)
        if other.count > 0 { other[0].text = item.locationText }
        if other.count > 1 { other[1].text = "Priority: \(item.priority)" }
        if other.count > 2 {
            if let d = item.createdAt {
                other[2].text = "Created: \(formatShortDate(d))"
            } else {
                other[2].text = "Created: —"
            }
        }

        // Switch handling
        sw?.isOn = selectedRequestIDs.contains(item.id)
        sw?.tag = item.id.hashValue
        sw?.accessibilityIdentifier = item.id
        sw?.removeTarget(self, action: nil, for: .valueChanged)
        sw?.addTarget(self, action: #selector(didChangeSwitch(_:)), for: .valueChanged)
    }

    // MARK: - Switch logic (max 3)
    @objc private func didChangeSwitch(_ sender: UISwitch) {
        guard let requestID = sender.accessibilityIdentifier else { return }

        if sender.isOn {
            if selectedRequestIDs.count >= 3 {
                sender.setOn(false, animated: true)
                showAlert(title: "Limit reached", message: "You can select maximum 3 tasks.")
                return
            }
            selectedRequestIDs.insert(requestID)
        } else {
            selectedRequestIDs.remove(requestID)
        }
    }

    // MARK: - Confirm
    @objc private func didTapConfirm() {
        guard let techUID = technicianUID, !techUID.isEmpty else {
            showAlert(title: "Missing Technician", message: "Technician ID is missing.")
            return
        }

        let chosen = Array(selectedRequestIDs)
        if chosen.isEmpty {
            showAlert(title: "No selection", message: "Select at least 1 task.")
            return
        }

        let techRef = db.collection("technicians").document(techUID)
        let now = Timestamp(date: Date())

        let batch = db.batch()

        // 1) Update technician assignedTaskCount by number of selected tasks
        batch.updateData([
            "assignedTaskCount": FieldValue.increment(Int64(chosen.count))
        ], forDocument: techRef)

        // 2) Update each request
        for requestID in chosen {
            let reqRef = db.collection("requests").document(requestID)
            batch.updateData([
                "assignedAt": now,
                "assignedTechnician": techRef
            ], forDocument: reqRef)
        }

        confirmButton?.isEnabled = false

        batch.commit { [weak self] err in
            guard let self else { return }
            self.confirmButton?.isEnabled = true

            if let err = err {
                print("❌ Batch commit failed: \(err)")
                self.showAlert(title: "Error", message: "Failed to assign tasks.")
                return
            }

            self.showAlert(title: "Done", message: "Assigned \(chosen.count) task(s).") {
                // Reload list (assigned ones should disappear)
                self.loadAndRender()
            }
        }
    }

    // MARK: - Search filter
    private func applyFilter(_ text: String) {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            filteredRequests = allRequests
        } else {
            filteredRequests = allRequests.filter { item in
                item.id.lowercased().contains(q)
                || item.title.lowercased().contains(q)
                || item.description.lowercased().contains(q)
                || item.locationText.lowercased().contains(q)
                || item.priority.lowercased().contains(q)
            }
        }
        renderList()
    }

    // MARK: - Helpers
    private func buildLocationText(from location: [String: Any]?) -> String {
        guard let location else { return "—" }
        let campus = (location["campus"] as? [String])?.first ?? "—"
        let building = (location["building"] as? [String])?.first ?? "—"
        let room = (location["room"] as? [String])?.first ?? "—"
        return "\(campus) - Building \(building) - Room \(room)"
    }

    private func formatShortDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        return df.string(from: date)
    }

    private func showAlert(title: String, message: String, onOK: (() -> Void)? = nil) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default) { _ in onOK?() })
        present(ac, animated: true)
    }

    // MARK: - View cloning
    private func cloneTemplateCard(_ template: UIView) -> UIView {
        // Snapshot-based cloning keeps your storyboard styling without rebuilding constraints.
        // It’s perfect for these “card views” inside stack view.
        // We’ll archive/unarchive to duplicate the view hierarchy.
        let data = try? NSKeyedArchiver.archivedData(withRootObject: template, requiringSecureCoding: false)
        let clone = (try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data ?? Data())) as? UIView
        let v = clone ?? UIView()
        v.isHidden = false
        return v
    }

    // MARK: - UI discovery (fallback if outlets not connected)
    private func findFirstStackView(in root: UIView?) -> UIStackView? {
        guard let root else { return nil }
        if let s = root as? UIStackView { return s }
        for sub in root.subviews {
            if let found = findFirstStackView(in: sub) { return found }
        }
        return nil
    }

    private func findSearchBar(in root: UIView?) -> UISearchBar? {
        guard let root else { return nil }
        if let sb = root as? UISearchBar { return sb }
        for sub in root.subviews {
            if let found = findSearchBar(in: sub) { return found }
        }
        return nil
    }

    private func findButton(withTitleContains str: String, in root: UIView?) -> UIButton? {
        guard let root else { return nil }
        if let b = root as? UIButton {
            let t = (b.title(for: .normal) ?? "") + " " + (b.configuration?.title ?? "")
            if t.lowercased().contains(str.lowercased()) { return b }
        }
        for sub in root.subviews {
            if let found = findButton(withTitleContains: str, in: sub) { return found }
        }
        return nil
    }

    private func findSwitch(in root: UIView?) -> UISwitch? {
        guard let root else { return nil }
        if let sw = root as? UISwitch { return sw }
        for sub in root.subviews {
            if let found = findSwitch(in: sub) { return found }
        }
        return nil
    }

    private func findLabels(in root: UIView?) -> [UILabel] {
        guard let root else { return [] }
        var out: [UILabel] = []
        if let l = root as? UILabel { out.append(l) }
        for sub in root.subviews {
            out.append(contentsOf: findLabels(in: sub))
        }
        return out
    }
}

// MARK: - UISearchBarDelegate
extension AdminTaskSelectionViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFilter(searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
