//
//  TechnScheduleViewController.swift
//  SignIn
//
//  Shows a calendar + technician assigned requests in a stack view
//

import UIKit
import FirebaseFirestore
import FSCalendar

final class TechnScheduleViewController: UIViewController, FSCalendarDataSource, FSCalendarDelegate {

    // MARK: - Passed in from TechListViewController
    var technicianUID: String!
    var technicianFullName: String = ""

    // MARK: - Storyboard Outlets (connect these)
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var datePicker: FSCalendar!
    @IBOutlet var tasksForLabel: UILabel!
    @IBOutlet var tasksDateLabel: UILabel!
    @IBOutlet var requestsStackView: UIStackView!

    private let db = Firestore.firestore()

    // We’ll use the first arranged subview as a template card (your storyboard already has sample cards).
    @IBOutlet var templateCard: UIView?

    // Current signed-in tech UID
    private var currentTechUID: String?
    
    // Keep listener so the list updates live
    private var listener: ListenerRegistration?

    // ✅ Store request days as stable keys (yyyy-MM-dd) in Bahrain timezone
    private var requestDayKeys: Set<String> = []

    // ✅ Always normalize selected date to Bahrain start-of-day
    private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    // ✅ Use a fixed timezone for all calendar + formatting logic
    private let appTimeZone = TimeZone(identifier: "Asia/Bahrain") ?? .current

    private lazy var appCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = appTimeZone
        return cal
    }()

    private lazy var dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = appCalendar
        f.timeZone = appTimeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        guard technicianUID != nil else {
            print("❌ TechnScheduleViewController: technicianUID is nil")
            return
        }

        datePicker.dataSource = self
        datePicker.delegate = self

        configureUI()
        setupTemplateCard()
        setupCalendar()

        // ✅ Initial: today in Bahrain start-of-day
        selectedDate = appCalendar.startOfDay(for: Date())

        // ✅ Dots for current month
        loadRequestDots(forMonthContaining: selectedDate)

        // ✅ Load initial day tasks
        loadAndRender(for: selectedDate)
    }

    deinit {
        listener?.remove()
    }

    // MARK: - UI
    private func configureUI() {
        if technicianFullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tasksForLabel.text = "Tasks for: (Unknown)"
        } else {
            tasksForLabel.text = "Tasks for: \(technicianFullName)"
        }
    }

    private func setupTemplateCard() {
        if let first = requestsStackView.arrangedSubviews.first {
            templateCard = first
            first.isHidden = true
        } else {
            print("❌ No template card found inside requestsStackView.")
        }
    }

    private func setupCalendar() {
        // event dot colors
        datePicker.appearance.eventDefaultColor = .red
        datePicker.appearance.eventSelectionColor = .red

        // Remove the default "today" filled circle highlight
        datePicker.appearance.todayColor = .clear
        datePicker.appearance.titleTodayColor = datePicker.appearance.titleDefaultColor

        datePicker.isUserInteractionEnabled = true
        view.bringSubviewToFront(datePicker)
    }


    // MARK: - FSCalendarDataSource (dots)
    func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
        // Normalize to Bahrain day key
        let key = dayKey(from: date)
        return requestDayKeys.contains(key) ? 1 : 0
    }

    // MARK: - FSCalendarDelegate (tap date)
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        let normalized = Calendar.current.startOfDay(for: date)
        let dayStart = appCalendar.startOfDay(for: date)
        selectedDate = dayStart
        tasksDateLabel.text = "Task On: \(formatDate(normalized))"
        loadAndRender(for: dayStart)
    }

    // MARK: - FSCalendarDelegate (page/month changed)
    func calendarCurrentPageDidChange(_ calendar: FSCalendar) {
        loadRequestDots(forMonthContaining: calendar.currentPage)
    }

    // MARK: - Month dots loader
    private func loadRequestDots(forMonthContaining date: Date) {
        guard let technicianUID else { return }

        let techRef = db.collection("technicians").document(technicianUID)

        // month boundaries in Bahrain timezone
        let comps = appCalendar.dateComponents([.year, .month], from: date)
        guard let monthStart = appCalendar.date(from: comps) else { return }
        guard let monthEnd = appCalendar.date(byAdding: .month, value: 1, to: monthStart) else { return }

        db.collection("requests")
            .whereField("assignedTechnician", isEqualTo: techRef)
            .whereField("assignedAt", isGreaterThanOrEqualTo: Timestamp(date: monthStart))
            .whereField("assignedAt", isLessThan: Timestamp(date: monthEnd))
            .getDocuments { [weak self] snap, err in
                guard let self else { return }

                if let err = err {
                    print("❌ loadRequestDots error:", err)
                    return
                }

                let docs = snap?.documents ?? []
                var keys = Set<String>()

                for d in docs {
                    if let ts = d.data()["assignedAt"] as? Timestamp {
                        keys.insert(self.dayKey(from: ts.dateValue()))
                    }
                }

                self.requestDayKeys = keys
                self.datePicker.reloadData()
            }
    }

    // MARK: - Data + Rendering
    private func loadAndRender(for selectedDate: Date) {
        listener?.remove()
        listener = nil
        clearGeneratedCards()

        guard let technicianUID else { return }
        let techRef = db.collection("technicians").document(technicianUID)

        let startOfDay = appCalendar.startOfDay(for: selectedDate)
        let endOfDay = appCalendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Debug prints that make sense in Bahrain time
        print("📅 Filtering (Bahrain):", dayKey(from: startOfDay), "->", dayKey(from: endOfDay))

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

    // MARK: - Helpers (stable key)
    private func dayKey(from date: Date) -> String {
        // Normalize into Bahrain day start (prevents “one day off”)
        let normalized = appCalendar.startOfDay(for: date)
        return dayKeyFormatter.string(from: normalized)
    }

    private func readLocationString(_ data: [String: Any]) -> String {
        guard let loc = data["location"] as? [String: Any] else { return "—" }

        let campus = (loc["campus"] as? [String])?.first ?? "—"
        let building = (loc["building"] as? [String])?.first ?? "—"
        let room = (loc["room"] as? [String])?.first ?? "—"

        return "\(campus) - \(building) - \(room)"
    }

    private func clearGeneratedCards() {
        for v in requestsStackView.arrangedSubviews {
            if v === templateCard { continue }
            requestsStackView.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
    }

    private func showEmptyStateCard() {
        guard let template = templateCard else { return }
        guard let card = cloneView(template) else { return }

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

        let ticket = (data["ticketNumber"] as? String) ?? docID
        let title = (data["title"] as? String) ?? (data["problemTitle"] as? String) ?? "Request"
        setLabelText(in: card, atIndex: 0, text: "#\(ticket) : \(title)")

        let locationText = readLocationString(data)
        setLabelText(in: card, atIndex: 1, text: locationText)

        let priorityRaw = (data["selectedPriorityLevel"] as? String) ?? "normal"
        let priorityText = "Priority: \(priorityRaw)"
        setLabelText(in: card, atIndex: 2, text: priorityText)

        applyPriorityColor(in: card, priority: priorityRaw)

        let dateText = formatDateFromAnyKnownField(data)
        setLabelText(in: card, atIndex: 3, text: dateText.isEmpty ? "" : "Date: \(dateText)")

        card.isHidden = false
        requestsStackView.addArrangedSubview(card)
        
        //button
        if let viewButton = card.viewWithTag(100) as? UIButton {
            print("✅ Button FOUND for request:", docID)
            viewButton.accessibilityIdentifier = docID
            viewButton.addTarget(self, action: #selector(viewRequestTapped(_:)), for: .touchUpInside)
        } else {
            print("❌ Button NOT found in card")
        }

    }
    
    @objc private func viewRequestTapped(_ sender: UIButton) {
        guard let requestId = sender.accessibilityIdentifier else {
            print("❌ Missing requestId")
            return
        }

        let sb = storyboard ?? UIStoryboard(name: "Main", bundle: nil)

        guard let vc = sb.instantiateViewController(
            withIdentifier: "ViewRequestViewController"
        ) as? ViewRequestViewController else {
            print("❌ ViewRequestViewController not found")
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

    private func applyPriorityColor(in card: UIView, priority: String) {
        let labels = allLabels(in: card)
        guard labels.indices.contains(2) else { return }
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

    private func setLabelText(in card: UIView, atIndex index: Int, text: String) {
        let labels = allLabels(in: card)
        guard index >= 0, index < labels.count else { return }
        labels[index].text = text
    }

    private func formatDateFromAnyKnownField(_ data: [String: Any]) -> String {
        let keys = ["scheduledStart", "startTime", "createdTime", "createdAt", "assignedAt"]
        for k in keys {
            if let ts = data[k] as? Timestamp {
                return formatDate(ts.dateValue())
            }
        }
        return ""
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = appCalendar
        f.timeZone = appTimeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}
