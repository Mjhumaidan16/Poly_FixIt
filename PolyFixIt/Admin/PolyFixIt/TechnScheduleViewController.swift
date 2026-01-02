//
//  TechnScheduleViewController.swift
//  SignIn
//
//  Calendar + assigned requests list (Bahrain-safe) + async/await dots + Swift-6 safe live listener
//

import UIKit
import FirebaseFirestore
import FSCalendar

final class TechnScheduleViewController: UIViewController,
                                        UISearchBarDelegate,
                                        FSCalendarDataSource,
                                        FSCalendarDelegate {

    // MARK: - Passed in from TechListViewController
    var technicianUID: String!
    var technicianFullName: String = ""

    // MARK: - Storyboard Outlets
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var datePicker: FSCalendar!
    @IBOutlet var tasksForLabel: UILabel!
    @IBOutlet var tasksDateLabel: UILabel!
    @IBOutlet var requestsStackView: UIStackView!

    // Optional (if you add it like the other controller)
    @IBOutlet weak var searchBar: UISearchBar?

    // Template card in the stack view
    @IBOutlet var templateCard: UIView?

    private let db = Firestore.firestore()

    // Live updates (Swift 6 safe async stream consumer task)
    private var listenTask: Task<Void, Never>?

    // Cache docs for rendering + search filtering
    private var allDocs: [(id: String, data: [String: Any])] = []
    private var filteredDocs: [(id: String, data: [String: Any])] = []

    // ✅ Store request days as stable keys (yyyy-MM-dd) in Bahrain timezone (for dots)
    private var requestDayKeys: Set<String> = []

    // ✅ Always normalize selected date to Bahrain start-of-day
    private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    // ✅ Fixed timezone for all calendar + formatting logic
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
        setupSearchBarIfExists()

        // ✅ Initial selection: today in Bahrain start-of-day
        selectedDate = appCalendar.startOfDay(for: Date())
        tasksDateLabel.text = "Task On: \(formatDate(selectedDate))"

        // ✅ Dots for current month (async/await)
        Task { [weak self] in
            guard let self else { return }
            await self.loadRequestDotsAsync(forMonthContaining: self.selectedDate)
        }

        // ✅ Live list for selected day (async listener stream)
        Task { [weak self] in
            guard let self else { return }
            await self.loadAndRenderAsync(for: self.selectedDate)
        }
    }

    deinit {
        listenTask?.cancel()
    }

    // MARK: - UI
    private func configureUI() {
        let name = technicianFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        tasksForLabel.text = name.isEmpty ? "Tasks for: (Unknown)" : "Tasks for: \(name)"
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
        // dots
        datePicker.appearance.eventDefaultColor = .red
        datePicker.appearance.eventSelectionColor = .red

        // Like your other one: make calendar text white (optional but common)
        datePicker.appearance.titleDefaultColor = .white
        datePicker.appearance.titleSelectionColor = .white
        datePicker.appearance.weekdayTextColor = .white
        datePicker.appearance.headerTitleColor = .white

        // Remove the default "today" filled circle highlight (like your Bahrain one)
        datePicker.appearance.todayColor = .clear
        datePicker.appearance.titleTodayColor = datePicker.appearance.titleDefaultColor

        datePicker.isUserInteractionEnabled = true
        view.bringSubviewToFront(datePicker)
    }

    private func setupSearchBarIfExists() {
        guard let searchBar else { return }
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.returnKeyType = .done
    }

    // MARK: - FSCalendarDataSource (dots)
    func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
        let key = dayKey(from: date) // Bahrain-stable
        return requestDayKeys.contains(key) ? 1 : 0
    }

    // MARK: - FSCalendarDelegate (tap date)
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        let dayStart = appCalendar.startOfDay(for: date)
        selectedDate = dayStart
        tasksDateLabel.text = "Task On: \(formatDate(dayStart))"

        // clear search when changing date (like your other controller)
        searchBar?.text = ""
        searchBar?.resignFirstResponder()

        Task { [weak self] in
            guard let self else { return }
            await self.loadAndRenderAsync(for: dayStart)
        }
    }

    // MARK: - FSCalendarDelegate (page/month changed)
    func calendarCurrentPageDidChange(_ calendar: FSCalendar) {
        Task { [weak self] in
            guard let self else { return }
            await self.loadRequestDotsAsync(forMonthContaining: calendar.currentPage)
        }
    }

    // MARK: - Month dots loader (async/await) (Bahrain-safe)
    private func loadRequestDotsAsync(forMonthContaining date: Date) async {
        guard let technicianUID else { return }

        let techRef = db.collection("technicians").document(technicianUID)

        // month boundaries in Bahrain timezone
        let comps = appCalendar.dateComponents([.year, .month], from: date)
        guard let monthStart = appCalendar.date(from: comps),
              let monthEnd = appCalendar.date(byAdding: .month, value: 1, to: monthStart)
        else { return }

        do {
            let snap = try await db.collection("requests")
                .whereField("assignedTechnician", isEqualTo: techRef)
                .whereField("assignedAt", isGreaterThanOrEqualTo: Timestamp(date: monthStart))
                .whereField("assignedAt", isLessThan: Timestamp(date: monthEnd))
                .getDocuments()

            var keys = Set<String>()
            for d in snap.documents {
                if let ts = d.data()["assignedAt"] as? Timestamp {
                    keys.insert(dayKey(from: ts.dateValue()))
                }
            }

            await MainActor.run {
                self.requestDayKeys = keys
                self.datePicker.reloadData()
            }
        } catch {
            print("❌ loadRequestDotsAsync error:", error)
        }
    }

    // MARK: - Data + Rendering (async live stream)
    private func loadAndRenderAsync(for date: Date) async {
        // stop old listener task
        listenTask?.cancel()
        listenTask = nil

        await MainActor.run {
            self.clearGeneratedCards()
        }

        guard let technicianUID else { return }
        let techRef = db.collection("technicians").document(technicianUID)

        let startOfDay = appCalendar.startOfDay(for: date)
        let endOfDay = appCalendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Debug prints in Bahrain time
        print("📅 Filtering (Bahrain):", dayKey(from: startOfDay), "->", dayKey(from: endOfDay))

        let q = db.collection("requests")
            .whereField("assignedTechnician", isEqualTo: techRef)
            .whereField("assignedAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("assignedAt", isLessThan: Timestamp(date: endOfDay))
            .order(by: "assignedAt", descending: false)

        let stream = makeSnapshotStream(for: q)

        listenTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await snap in stream {
                    let docs = snap.documents
                    self.allDocs = docs.map { ($0.documentID, $0.data()) }

                    await MainActor.run {
                        self.applySearchAndRender(for: startOfDay)
                    }
                }
            } catch {
                print("❌ TechnSchedule query error:", error)
            }
        }
    }

    // ✅ Wrap addSnapshotListener into AsyncThrowingStream (Swift 6 safe)
    private func makeSnapshotStream(for query: Query) -> AsyncThrowingStream<QuerySnapshot, Error> {

        actor RegistrationStore {
            private var reg: ListenerRegistration?
            func set(_ newReg: ListenerRegistration?) { reg = newReg }
            func remove() { reg?.remove(); reg = nil }
        }

        let store = RegistrationStore()

        return AsyncThrowingStream { continuation in
            let reg = query.addSnapshotListener { snap, err in
                if let err = err {
                    continuation.finish(throwing: err)
                    return
                }
                if let snap = snap {
                    continuation.yield(snap)
                }
            }

            Task { await store.set(reg) }

            continuation.onTermination = { _ in
                Task { await store.remove() }
            }
        }
    }

    // MARK: - Search + Render
    private func applySearchAndRender(for selectedDayStart: Date) {
        clearGeneratedCards()

        let term = (searchBar?.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // allDocs is already day-filtered by the query, but keep it safe
        var docsForDay = allDocs.filter { pair in
            guard let ts = pair.data["assignedAt"] as? Timestamp else { return false }
            return appCalendar.startOfDay(for: ts.dateValue()) == selectedDayStart
        }

        if !term.isEmpty {
            docsForDay = docsForDay.filter { pair in
                let data = pair.data
                let title = ((data["title"] as? String) ?? (data["problemTitle"] as? String) ?? "").lowercased()
                let loc = readLocationString(data).lowercased()
                let pr = ((data["selectedPriorityLevel"] as? String) ?? "").lowercased()
                let ticket = ((data["ticketNumber"] as? String) ?? pair.id).lowercased()

                return title.contains(term) || loc.contains(term) || pr.contains(term) || ticket.contains(term)
            }
        }

        filteredDocs = docsForDay

        if filteredDocs.isEmpty {
            showEmptyStateCard(message: term.isEmpty ? "No tasks found" : "No results for \"\(searchBar?.text ?? "")\"")
            return
        }

        for item in filteredDocs {
            addCard(for: item.data, docID: item.id)
        }
    }

    // MARK: - Helpers (stable key)
    private func dayKey(from date: Date) -> String {
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

    private func showEmptyStateCard(message: String) {
        guard let template = templateCard else { return }
        guard let card = cloneView(template) else { return }

        applyCardCornerRadius(card)

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

        applyCardCornerRadius(card)

        let ticket = (data["ticketNumber"] as? String) ?? docID
        let title = (data["title"] as? String) ?? (data["problemTitle"] as? String) ?? "Request"
        setLabelText(in: card, atIndex: 0, text: "#\(ticket) : \(title)")

        let locationText = readLocationString(data)
        setLabelText(in: card, atIndex: 1, text: locationText)

        let priorityRaw = (data["selectedPriorityLevel"] as? String) ?? "normal"
        setLabelText(in: card, atIndex: 2, text: "Priority: \(priorityRaw)")
        applyPriorityColor(in: card, priority: priorityRaw)

        let dateText = formatDateFromAnyKnownField(data)
        setLabelText(in: card, atIndex: 3, text: dateText.isEmpty ? "" : "Date: \(dateText)")

        // ✅ Keep YOUR SAME logic: button tag 100 opens ViewRequestViewController
        if let viewButton = card.viewWithTag(100) as? UIButton {
            viewButton.isUserInteractionEnabled = true
            viewButton.isEnabled = true
            viewButton.alpha = 1.0

            viewButton.accessibilityIdentifier = docID
            viewButton.removeTarget(nil, action: nil, for: .allEvents)
            viewButton.addTarget(self, action: #selector(viewRequestTapped(_:)), for: .touchUpInside)
        } else {
            print("❌ Button(tag 100) NOT found in card")
        }

        card.isHidden = false
        requestsStackView.addArrangedSubview(card)
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

    // MARK: - UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applySearchAndRender(for: selectedDate)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        applySearchAndRender(for: selectedDate)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        applySearchAndRender(for: selectedDate)
    }
}

// Same helper you used in the other file
private func applyCardCornerRadius(_ card: UIView) {
    card.layer.cornerRadius = 10
    card.layer.masksToBounds = true
}
