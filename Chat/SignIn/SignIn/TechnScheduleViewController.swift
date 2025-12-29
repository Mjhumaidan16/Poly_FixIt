//
//  TechnScheduleViewController.swift
//  SignIn
//
//  Shows a calendar + current technician assigned requests in a stack view
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

final class TechnScheduleViewController: UIViewController, UISearchBarDelegate {

    // MARK: - Storyboard Outlets (connect these)
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var datePicker: UIDatePicker!          // storyboard: xUg-Qf-ZSc
    @IBOutlet weak var tasksForLabel: UILabel!            // storyboard: 5g1-pR-eg0
    @IBOutlet weak var searchBar: UISearchBar!            // storyboard: 7rs-RG-lLR
    @IBOutlet weak var requestsStackView: UIStackView!    // the vertical list container

    // We’ll use the first arranged subview as a template card (your storyboard already has sample cards).
    @IBOutlet var templateCard: UIView?

    private let db = Firestore.firestore()

    // Keep listener so the list updates live
    private var listener: ListenerRegistration?

    // Current signed-in tech UID
    private var currentTechUID: String?

    // Cache docs for search filtering
    private var allDocs: [(id: String, data: [String: Any])] = []
    private var filteredDocs: [(id: String, data: [String: Any])] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // --- Current user only (manual override for testing) ---
        #if DEBUG
            // 🔧 TEMP: hardcoded technician UID for testing
            let uid = "AXCu0meKf2Uf3cBXM8InRTPBaNf1"   // <-- put your technician UID here
            currentTechUID = uid
            print("🧪 DEBUG MODE: using manual technician UID:", uid)
        #else
            guard let uid = Auth.auth().currentUser?.uid else {
                print("❌ No logged-in user. Cannot load technician schedule.")
                tasksForLabel.text = "Task On: —"
                return
            }
            currentTechUID = uid
        #endif

        configureUI()
        setupTemplateCard()
        setupDatePicker()
        setupSearchBar()

        // Load initial day (today)
        loadAndRender(for: datePicker.date)
    }

    deinit {
        listener?.remove()
    }

    // MARK: - UI
    private func configureUI() {
        // Your storyboard label is "Task On: ..."
        tasksForLabel.text = "Task On: \(formatHeaderDate(datePicker.date))"
    }

    private func setupTemplateCard() {
        // Use the first card in the stack view as a template
        if let first = requestsStackView.arrangedSubviews.first {
            templateCard = first
            first.isHidden = true // hide template
        } else {
            print("❌ No template card found inside requestsStackView.")
        }
    }

    private func setupDatePicker() {
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.isUserInteractionEnabled = true

        datePicker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)

        // (Your previous debug/interaction forcing - kept safe)
        datePicker.superview?.bringSubviewToFront(datePicker)
        view.bringSubviewToFront(datePicker)
        datePicker.isEnabled = true
        datePicker.superview?.isUserInteractionEnabled = true
    }

    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.returnKeyType = .done
    }

    @objc private func dateChanged(_ sender: UIDatePicker) {
        tasksForLabel.text = "Task On: \(formatHeaderDate(sender.date))"
        // Clear search text when day changes (so user doesn't think results are missing)
        searchBar.text = ""
        searchBar.resignFirstResponder()

        loadAndRender(for: sender.date)
    }

    // MARK: - Data + Rendering
    private func loadAndRender(for selectedDate: Date) {
        listener?.remove()
        listener = nil
        clearGeneratedCards()

        guard let uid = currentTechUID else { return }

        // requests.assignedTechnician is a reference to technicians/<uid>
        let techRef = db.collection("technicians").document(uid)

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: selectedDate)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!

        let q = db.collection("requests")
            .whereField("assignedTechnician", isEqualTo: techRef)
            .whereField("assignedAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("assignedAt", isLessThan: Timestamp(date: endOfDay))
            .order(by: "assignedAt", descending: false)

        listener = q.addSnapshotListener { [weak self] snap, err in
            guard let self else { return }
            if let err = err {
                print("❌ TechnSchedule query error:", err)
                return
            }

            let docs = snap?.documents ?? []
            self.allDocs = docs.map { ($0.documentID, $0.data()) }

            // Apply search (if any) then render
            self.applySearchAndRender()
        }
    }

    private func applySearchAndRender() {
        clearGeneratedCards()

        let term = (searchBar.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if term.isEmpty {
            filteredDocs = allDocs
        } else {
            filteredDocs = allDocs.filter { pair in
                let data = pair.data
                let title = ((data["title"] as? String) ?? (data["problemTitle"] as? String) ?? "").lowercased()
                let loc = readLocationString(data).lowercased()
                let selectedPriorityLevel = ((data["selectedPriorityLevel"] as? String) ?? "").lowercased()

                return title.contains(term)
                    || loc.contains(term)
                    || selectedPriorityLevel.contains(term)
            }
        }

        if filteredDocs.isEmpty {
            showEmptyStateCard(message: term.isEmpty ? "No tasks found" : "No results for \"\(searchBar.text ?? "")\"")
            return
        }

        for item in filteredDocs {
            addCard(for: item.data, docID: item.id)
        }
    }

    // MARK: - UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applySearchAndRender()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        applySearchAndRender()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        applySearchAndRender()
    }

    // MARK: - Card Rendering
    private func showEmptyStateCard(message: String) {
        guard let template = templateCard else { return }
        guard let card = cloneView(template) else { return }

        // Your card has 4 labels:
        // [0] title
        // [1] location
        // [2] priority
        // [3] created
        setLabelText(in: card, atIndex: 0, text: message)
        setLabelText(in: card, atIndex: 1, text: "Pick another day or check assignments")
        setLabelText(in: card, atIndex: 2, text: "")
        setLabelText(in: card, atIndex: 3, text: "")

        card.isHidden = false
        requestsStackView.addArrangedSubview(card)
    }

    private func addCard(for data: [String: Any], docID: String) {
        guard let template = templateCard else {
            print("❌ templateCard is nil in addCard")
            return
        }
        guard let card = cloneView(template) else {
            print("❌ cloneView returned nil")
            return
        }

        // --- Title ---
        let title = (data["title"] as? String) ?? (data["problemTitle"] as? String) ?? "Request"
        setLabelText(in: card, atIndex: 0, text: "\(title):")

        // --- Location ---
        let locationText = readLocationString(data)
        setLabelText(in: card, atIndex: 1, text: locationText)

        // --- Priority (COLOR RULE) ---
        let priorityRaw = (data["selectedPriorityLevel"] as? String) ?? "normal"
        let priorityText = "Priority: \(priorityRaw)"
        setLabelText(in: card, atIndex: 2, text: priorityText)

        // If priority == "high" -> red, else keep white/default
        applyPriorityColor(in: card, priority: priorityRaw)

        // --- Created / Date ---
        let createdText = formatDateFromAnyKnownField(data)
        setLabelText(in: card, atIndex: 3, text: createdText.isEmpty ? "" : "Created: \(createdText)")
        
        // ✅ Attach button -> open details, pass requestId
        if let button = findFirstButton(in: card) {
            // store requestId on the button
            button.accessibilityIdentifier = docID

            // prevent duplicates (important when reusing template)
            button.removeTarget(nil, action: nil, for: .allEvents)
            button.addTarget(self, action: #selector(openTaskDetails(_:)), for: .touchUpInside)
        } else {
            print("⚠️ No button found inside template card. Add one or check hierarchy.")
        }

        card.isHidden = false
        requestsStackView.addArrangedSubview(card)
    }

    @objc private func openTaskDetails(_ sender: UIButton) {
        guard let requestId = sender.accessibilityIdentifier, !requestId.isEmpty else { return }

        let sb = storyboard ?? UIStoryboard(name: "Main", bundle: nil)
        guard let vc = sb.instantiateViewController(withIdentifier: "TechViewRequestViewController") as? TechViewRequestViewController else {
            print("❌ Could not instantiate TechViewRequestViewController (check Storyboard ID).")
            return
        }

        vc.requestId = requestId

        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
    }

    
    private func applyPriorityColor(in card: UIView, priority: String) {
        let labels = allLabels(in: card)
        guard labels.indices.contains(2) else { return }
        let priorityLabel = labels[2]

        if priority.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "high" {
            priorityLabel.textColor = .red
        } else {
            // Match your storyboard "white" behavior
            priorityLabel.textColor = .white
        }
    }

    // MARK: - Helpers (cloning + label mapping)
    private func clearGeneratedCards() {
        for v in requestsStackView.arrangedSubviews {
            if v === templateCard { continue }
            requestsStackView.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
    }
    
    private func findFirstButton(in root: UIView) -> UIButton? {
        if let b = root as? UIButton { return b }
        for s in root.subviews {
            if let b = findFirstButton(in: s) { return b }
        }
        return nil
    }


    private func cloneView(_ view: UIView) -> UIView? {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: view, requiringSecureCoding: false)
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            defer { unarchiver.finishDecoding() }
            return unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? UIView
        } catch {
            print("❌ cloneView failed:", error)
            return nil
        }
    }

    private func allLabels(in root: UIView) -> [UILabel] {
        var result: [UILabel] = []
        func walk(_ v: UIView) {
            for s in v.subviews {
                if let l = s as? UILabel { result.append(l) }
                walk(s)
            }
        }
        walk(root)
        return result
    }

    private func setLabelText(in card: UIView, atIndex index: Int, text: String) {
        let labels = allLabels(in: card)
        guard index >= 0, index < labels.count else { return }
        labels[index].text = text
    }

    private func readLocationString(_ data: [String: Any]) -> String {
        guard let loc = data["location"] as? [String: Any] else { return "—" }

        let campus = (loc["campus"] as? [String])?.first ?? "—"
        let building = (loc["building"] as? [String])?.first ?? "—"
        let room = (loc["room"] as? [String])?.first ?? "—"

        return "\(campus) - \(building) - \(room)"
    }

    private func formatDateFromAnyKnownField(_ data: [String: Any]) -> String {
        let keys = ["scheduledStart", "startTime", "createdTime", "createdAt", "assignedAt"]
        for k in keys {
            if let ts = data[k] as? Timestamp {
                return formatCardDate(ts.dateValue())
            }
        }
        return ""
    }

    private func formatCardDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    private func formatHeaderDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        return f.string(from: date)
    }
}
