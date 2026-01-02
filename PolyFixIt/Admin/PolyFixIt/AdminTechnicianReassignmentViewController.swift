import UIKit
import FirebaseFirestore

final class AdminTechnicianReassignmentViewController: UIViewController {

    // MARK: - Passed in (MUST be set before presenting)
    var requestID: String!

    // MARK: - Firestore
    private let db = Firestore.firestore()

    // MARK: - UI Outlets (optional; code can auto-find)
    @IBOutlet private var techniciansStackView: UIStackView?
    @IBOutlet private var searchBar: UISearchBar?
    @IBOutlet private var confirmButton: UIButton?
    @IBOutlet private var segmentedControl: UISegmentedControl?

    // Template card (first arrangedSubview in storyboard stack)
    @IBOutlet private var templateCardView: UIView?

    // MARK: - Internal state
    private var allTechs: [TechItem] = []
    private var filteredTechs: [TechItem] = []
    private var selectedTechUID: String?
    private var renderToken = UUID()

    // MARK: - Model
    private struct TechItem {
        let uid: String
        let name: String
        let Department: String
        let assignedTaskCount: Int
        let ongoingTitle: String
        let isBusy: Bool
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        if requestID == nil || requestID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("❌ requestID is missing. Pass it before presenting this VC.")
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

        // Segmented control (All / Free / Busy)
        if segmentedControl == nil {
            segmentedControl = findFirstSegmentedControl(in: view)
        }
        segmentedControl?.addTarget(self, action: #selector(didChangeSegment), for: .valueChanged)

        // Stack view
        if techniciansStackView == nil {
            techniciansStackView = findFirstStackView(in: view)
        }

        // Template card (first arrangedSubview inside stack)
        if let stack = techniciansStackView {
            templateCardView = stack.arrangedSubviews.first
            templateCardView?.isHidden = true
        }
    }

    // MARK: - Data Load
    private func loadAndRender() {
        let myToken = UUID()
        renderToken = myToken

        db.collection("technicians").getDocuments { [weak self] snap, err in
            guard let self else { return }
            guard self.renderToken == myToken else { return }

            if let err = err {
                print("❌ Failed to fetch technicians: \(err)")
                self.showAlert(title: "Error", message: "Failed to fetch technicians.")
                return
            }

            let docs = snap?.documents ?? []
            self.allTechs = docs.map { doc in
                let data = doc.data()

                let name = (data["name"] as? String)
                    ?? (data["fullName"] as? String)
                    ?? "Unknown"

                let specialty = (data["Department"] as? String)
                    ?? "Technician"

                let assigned = (data["assignedTaskCount"] as? Int)
                    ?? Int((data["assignedTaskCount"] as? Int64) ?? 0)

                // Optional fields (safe defaults)
                let ongoingTitle = (data["ongoingTaskTitle"] as? String) ?? ""
                let isBusy = (data["isBusy"] as? Bool) ?? (assigned > 0)

                return TechItem(
                    uid: doc.documentID,
                    name: name,
                    Department: specialty,
                    assignedTaskCount: assigned,
                    ongoingTitle: ongoingTitle,
                    isBusy: isBusy
                )
            }

            self.applyCurrentFiltersAndRender()
        }
    }

    // MARK: - Filtering + Render
    @objc private func didChangeSegment() {
        applyCurrentFiltersAndRender()
    }

    private func applyCurrentFiltersAndRender() {
        let seg = segmentedControl?.selectedSegmentIndex ?? 0

        // 0=All, 1=Free, 2=Busy (based on your storyboard segments)
        let base: [TechItem]
        switch seg {
        case 1:
            base = allTechs.filter { !$0.isBusy }
        case 2:
            base = allTechs.filter { $0.isBusy }
        default:
            base = allTechs
        }

        let text = (searchBar?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.isEmpty {
            filteredTechs = base
        } else {
            filteredTechs = base.filter { t in
                t.uid.lowercased().contains(text)
                || t.name.lowercased().contains(text)
                || t.Department.lowercased().contains(text)
            }
        }

        renderList()
    }

    private func renderList() {
        guard let stack = techniciansStackView else { return }

        // Clear generated cards (keep template only)
        for v in stack.arrangedSubviews {
            if v === templateCardView { continue }
            stack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }

        guard let template = templateCardView else {
            print("❌ No template card found. Add 1 sample technician card view inside the stack in storyboard.")
            return
        }

        for tech in filteredTechs {
            let card = cloneTemplateCard(template)
            configure(card: card, tech: tech)
            stack.addArrangedSubview(card)
        }
    }

    private func configure(card: UIView, tech: TechItem) {
        let sw = findSwitch(in: card)

        // Name: prefer a tagged label, otherwise fallback to biggest font
        let nameLabel = card.viewWithTag(1001) as? UILabel
            ?? findLabels(in: card).max(by: { $0.font.pointSize < $1.font.pointSize })

        // ID / Tasks / Ongoing (optional tags)
        let idLabel = card.viewWithTag(1002) as? UILabel
        let tasksLabel = card.viewWithTag(1003) as? UILabel
        let ongoingLabel = card.viewWithTag(1006) as? UILabel

        // ✅ The two you want fixed (BUSY vs CATEGORY)
        let busyLabel = card.viewWithTag(1004) as? UILabel
        let categoryLabel = card.viewWithTag(1005) as? UILabel

        nameLabel?.text = tech.name
        idLabel?.text = "ID: \(tech.uid)"
        tasksLabel?.text = "\(tech.assignedTaskCount) Tasks Assigned"
        ongoingLabel?.text = tech.ongoingTitle.isEmpty ? "Ongoing: —" : "Ongoing: \(tech.ongoingTitle)"

        // ✅ correct placement
        busyLabel?.text = tech.isBusy ? "Busy" : "Free"
        busyLabel?.textAlignment = .center

        categoryLabel?.text = tech.Department

        // Switch (single selection)
        sw?.removeTarget(self, action: nil, for: .valueChanged)
        sw?.accessibilityIdentifier = tech.uid
        sw?.isOn = (selectedTechUID == tech.uid)
        sw?.addTarget(self, action: #selector(didChangeSwitch(_:)), for: .valueChanged)
    }


    @objc private func didChangeSwitch(_ sender: UISwitch) {
        guard let techUID = sender.accessibilityIdentifier else { return }

        if sender.isOn {
            // enforce single selection
            selectedTechUID = techUID
        } else {
            if selectedTechUID == techUID { selectedTechUID = nil }
        }

        // Re-render to turn off other switches
        renderList()
    }

    // MARK: - Confirm reassignment
    @objc private func didTapConfirm() {
        let rid = (requestID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rid.isEmpty else {
            showAlert(title: "Missing Request", message: "requestID is missing.")
            return
        }

        guard let newTechUID = selectedTechUID, !newTechUID.isEmpty else {
            showAlert(title: "No selection", message: "Select 1 technician.")
            return
        }

        confirmButton?.isEnabled = false

        let requestRef = db.collection("requests").document(rid)
        let newTechRef = db.collection("technicians").document(newTechUID)
        let now = Timestamp(date: Date())

        // Transaction: read current request assignment, update counts + assignedTechnician atomically
        db.runTransaction({ (tx, errPtr) -> Any? in
            let reqSnap: DocumentSnapshot
            do {
                reqSnap = try tx.getDocument(requestRef)
            } catch {
                errPtr?.pointee = error as NSError
                return nil
            }

            let data = reqSnap.data() ?? [:]
            let oldTechRef = data["assignedTechnician"] as? DocumentReference

            // If reassigning to same technician, no-op counts (still update timestamp if you want)
            if oldTechRef?.path == newTechRef.path {
                tx.updateData([
                    "assignedAt": now,
                    "assignedTechnician": newTechRef,
                    "reassignedAt": now
                ], forDocument: requestRef)
                return nil
            }

            // decrement old tech count if exists
            if let old = oldTechRef {
                tx.updateData([
                    "assignedTaskCount": FieldValue.increment(Int64(-1))
                ], forDocument: old)
            }

            // increment new tech count
            tx.updateData([
                "assignedTaskCount": FieldValue.increment(Int64(1))
            ], forDocument: newTechRef)

            // update request assignment
            tx.updateData([
                "assignedAt": now,
                "assignedTechnician": newTechRef,
                "reassignedAt": now
            ], forDocument: requestRef)

            return nil
        }, completion: { [weak self] _, err in
            guard let self else { return }
            self.confirmButton?.isEnabled = true

            if let err = err {
                print("❌ Reassignment failed: \(err)")
                self.showAlert(title: "Error", message: "Failed to reassign technician.")
                return
            }

            self.showAlert(title: "Done", message: "Technician reassigned.") {
                self.selectedTechUID = nil
                self.loadAndRender()
            }
        })
    }

    // MARK: - Alert
    private func showAlert(title: String, message: String, onOK: (() -> Void)? = nil) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default) { _ in onOK?() })
        present(ac, animated: true)
    }

    // MARK: - View cloning (same style as your reference)
    private func cloneTemplateCard(_ template: UIView) -> UIView {
        let data = try? NSKeyedArchiver.archivedData(withRootObject: template, requiringSecureCoding: false)
        let clone = (try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data ?? Data())) as? UIView
        let v = clone ?? UIView()
        v.isHidden = false
        return v
    }

    // MARK: - UI discovery helpers (same pattern as your reference)
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

    private func findFirstSegmentedControl(in root: UIView?) -> UISegmentedControl? {
        guard let root else { return nil }
        if let sc = root as? UISegmentedControl { return sc }
        for sub in root.subviews {
            if let found = findFirstSegmentedControl(in: sub) { return found }
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
extension AdminTechnicianReassignmentViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyCurrentFiltersAndRender()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
