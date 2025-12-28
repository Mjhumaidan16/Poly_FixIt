//
//  TechnScheduleViewController.swift
//  SignIn
//
//  Shows a calendar + technician assigned requests in a stack view
//

import UIKit
import FirebaseFirestore

final class TechnScheduleViewController: UIViewController {

    // MARK: - Passed in from TechListViewController
    var technicianUID: String!
    var technicianFullName: String = ""

    // MARK: - Storyboard Outlets (connect these)
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet var datePicker: UIDatePicker!          // your inline datePicker (gsJ-fB-Gac)
    @IBOutlet var tasksForLabel: UILabel!            // label "Tasks for: ..." (bTe-Vm-MV6)
    @IBOutlet var requestsStackView: UIStackView!    // vertical stack view (1qt-0G-KPV)

    private let db = Firestore.firestore()

    // We’ll use the first arranged subview as a template card (your storyboard already has sample cards).
    @IBOutlet var templateCard: UIView?

    // Keep listener so the list updates live
    private var listener: ListenerRegistration?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        guard technicianUID != nil else {
            print("❌ TechnScheduleViewController: technicianUID is nil")
            return
        }
        
        
        // Make sure it’s above anything that might overlap it
            datePicker.superview?.bringSubviewToFront(datePicker)
            view.bringSubviewToFront(datePicker)

            // Force interaction
            datePicker.isEnabled = true
            datePicker.isUserInteractionEnabled = true
            datePicker.superview?.isUserInteractionEnabled = true

            // Debug: show who is actually receiving taps at the datePicker center
            let p = datePicker.convert(CGPoint(x: datePicker.bounds.midX, y: datePicker.bounds.midY), to: view)
        if let hit = view.hitTest(p, with: nil) {
            print("👆 datePicker center HIT:", type(of: hit), "frame:", hit.frame, "alpha:", hit.alpha, "hidden:", hit.isHidden)
        }
        configureUI()
        setupTemplateCard()
        setupDatePicker()
    }

       deinit {
           listener?.remove()
       }
    
    // MARK: - UI
    private func configureUI() {
        // Fill "Tasks for: <name>"
        if technicianFullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tasksForLabel.text = "Tasks for: (Unknown)"
        } else {
            tasksForLabel.text = "Tasks for: \(technicianFullName)"
        }
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
        datePicker.isUserInteractionEnabled = true
        datePicker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)
        datePicker.preferredDatePickerStyle = .inline
    }


    @objc private func dateChanged(_ sender: UIDatePicker) {
        print("✅ dateChanged sender.date =", sender.date, "outlet.date =", datePicker.date)
        loadAndRender(for: sender.date)
    }

    // MARK: - Data + Rendering
    
    private func loadAndRender(for selectedDate: Date) {
        listener?.remove()
        listener = nil
        clearGeneratedCards()

        guard let technicianUID else { return }
        let techRef = db.collection("technicians").document(technicianUID)

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: selectedDate)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!

        print("📅 Filtering:", startOfDay, "->", endOfDay)

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

            self.clearGeneratedCards()
            let docs = snap?.documents ?? []
            print("✅ Found docs:", docs.count)

            if docs.isEmpty {
                self.showEmptyStateCard()
                return
            }

            for d in docs {
                self.addCard(for: d.data(), docID: d.documentID)
            }
        }
    }

    private func readLocationString(_ data: [String: Any]) -> String {
        guard let loc = data["location"] as? [String: Any] else { return "—" }

        let campus = (loc["campus"] as? [String])?.first ?? "—"
        let building = (loc["building"] as? [String])?.first ?? "—"
        let room = (loc["room"] as? [String])?.first ?? "—"

        return "\(campus) - \(building) - \(room)"
    }


    private func attachListener(query: Query) {
        listener = query.addSnapshotListener { [weak self] snap, err in
            guard let self = self else { return }

            if let err = err {
                print("❌ requests listener error: \(err)")
                return
            }

            self.clearGeneratedCards()

            let docs = snap?.documents ?? []
            if docs.isEmpty {
                self.showEmptyStateCard()
                return
            }

            for d in docs {
                self.addCard(for: d.data(), docID: d.documentID)
            }
        }
    }

    private func clearGeneratedCards() {
        // Remove all arranged subviews except template
        for v in requestsStackView.arrangedSubviews {
            if v === templateCard { continue }
            requestsStackView.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
    }

    private func showEmptyStateCard() {
        guard let template = templateCard else { return }
        guard let card = cloneView(template) else { return }

        // Fill labels with an empty message
        setLabelText(in: card, atIndex: 0, text: "No tasks found")
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
        // Your storyboard sample card has 4 labels:
        // [0] title (big) e.g. "#T-123 : HVAC – AC not cooling"
        // [1] location line
        // [2] priority line
        // [3] created line

        // --- Title ---
        let ticket = (data["ticketNumber"] as? String) ?? docID
        let title = (data["title"] as? String) ?? (data["problemTitle"] as? String) ?? "Request"
        setLabelText(in: card, atIndex: 0, text: "#\(ticket) : \(title)")

        // --- Location ---
        let locationText = readLocationString(data)
        setLabelText(in: card, atIndex: 1, text: locationText)

        // --- Priority (COLOR RULE) ---
        let priorityRaw = (data["selectedPriorityLevel"] as? String) ?? "normal"
        let priorityText = "Priority: \(priorityRaw)"
        setLabelText(in: card, atIndex: 2, text: priorityText)

        // If priority == "high" -> red, else white
        applyPriorityColor(in: card, priority: priorityRaw)

        // --- Created / Date ---
        let dateText = formatDateFromAnyKnownField(data)
        setLabelText(in: card, atIndex: 3, text: dateText.isEmpty ? "" : "Date: \(dateText)")

        // Optional: if you have a button in the card, you can attach action here.

        card.isHidden = false
        requestsStackView.addArrangedSubview(card)
    }

    // MARK: - Helpers (cloning + label mapping)

    private func cloneView(_ view: UIView) -> UIView? {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: view, requiringSecureCoding: false)

            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            defer { unarchiver.finishDecoding() }

            // Decode the root object of the archive
            return unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? UIView
        } catch {
            print("❌ cloneView failed:", error)
            return nil
        }
    }
    
    private func applyPriorityColor(in card: UIView, priority: String) {
        let labels = allLabels(in: card)
        guard labels.indices.contains(2) else { return }   // index 2 is your priority label
        let priorityLabel = labels[2]

        if priority.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "high" {
            priorityLabel.textColor = .red
        } else {
            priorityLabel.textColor = .white
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

    // We fill labels by their order in the view hierarchy. Your card has 4 labels.
    private func setLabelText(in card: UIView, atIndex index: Int, text: String) {
        let labels = allLabels(in: card)
        guard index >= 0, index < labels.count else { return }
        labels[index].text = text
    }

    private func formatDateFromAnyKnownField(_ data: [String: Any]) -> String {
        // Try common keys
        let keys = ["scheduledStart", "startTime", "createdTime", "createdAt"]
        for k in keys {
            if let ts = data[k] as? Timestamp {
                return formatDate(ts.dateValue())
            }
        }
        return ""
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}
