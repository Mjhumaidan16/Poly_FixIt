//
//  TechnScheduleViewController.swift
//  SignIn
//
//  Shows a calendar + current technician assigned requests in a stack view
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FSCalendar

final class TechnScheduleViewController: UIViewController, UISearchBarDelegate, FSCalendarDataSource, FSCalendarDelegate {

    // MARK: - Storyboard Outlets (connect these)
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var datePicker: FSCalendar!          // storyboard: xUg-Qf-ZSc
    @IBOutlet weak var tasksForLabel: UILabel!          // storyboard: 5g1-pR-eg0
    @IBOutlet weak var searchBar: UISearchBar!          // storyboard: 7rs-RG-lLR
    @IBOutlet weak var requestsStackView: UIStackView!  // the vertical list container

    // We’ll use the first arranged subview as a template card (your storyboard already has sample cards).
    @IBOutlet var templateCard: UIView?

    private let db = Firestore.firestore()

    // Keep listener so the list updates live
    private var listener: ListenerRegistration?

    //  Task that consumes the async snapshot stream
    private var listenTask: Task<Void, Never>?

    // Current signed-in tech UID
    private var currentTechUID: String?

    // Cache docs for search filtering
    private var allDocs: [(id: String, data: [String: Any])] = []
    private var filteredDocs: [(id: String, data: [String: Any])] = []

    // Dates with requests for dot markers (MONTH scope)
    private var requestDates: [Date] = []

    // Currently selected date on the calendar
    private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let uid = Auth.auth().currentUser?.uid else {
            print(" No logged-in user. Cannot load technician schedule.")
            tasksForLabel.text = "Task On: —"
            return
        }
        currentTechUID = uid

        print(currentTechUID!)

        datePicker.dataSource = self
        datePicker.delegate = self
        datePicker.appearance.eventDefaultColor = .red
        datePicker.appearance.eventSelectionColor = .red

        configureUI()
        setupTemplateCard()
        setupDatePicker()
        setupSearchBar()

        //  Dots for current month (async/await)
        Task { [weak self] in
            guard let self else { return }
            await self.loadRequestDotsAsync(forMonthContaining: Date())
        }

        //  Load initial day (today start-of-day) (async/await + async listener)
        selectedDate = Calendar.current.startOfDay(for: Date())
        Task { [weak self] in
            guard let self else { return }
            await self.loadAndRenderAsync(for: self.selectedDate)
        }
    }

    deinit {
        listener?.remove()
        listenTask?.cancel()
    }

    // MARK: - UI
    private func configureUI() {
        tasksForLabel.text = "Task On: \(formatHeaderDate(selectedDate))"
    }

    private func setupTemplateCard() {
        if let first = requestsStackView.arrangedSubviews.first {
            templateCard = first
            first.isHidden = true
        } else {
            print(" No template card found inside requestsStackView.")
        }
    }
    
    private func setupDatePicker() {
        datePicker.dataSource  = self
        datePicker.delegate    = self
        datePicker.isUserInteractionEnabled = true
        view.bringSubviewToFront(datePicker)

        //dots
        datePicker.appearance.eventDefaultColor = .red
        datePicker.appearance.eventSelectionColor = .red

        //TEXT COLORS → WHITE
        datePicker.appearance.titleDefaultColor = .white        // normal days
        datePicker.appearance.titleSelectionColor = .white      // selected day
        datePicker.appearance.weekdayTextColor = .white         // Sun–Sat labels
        datePicker.appearance.headerTitleColor = .white         // Month title

        //the default "today" circle highlight
        datePicker.appearance.todayColor = .blue
        datePicker.appearance.titleTodayColor = .white
    }


    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.returnKeyType = .done
    }

    // MARK: - Month dots loader (IMPORTANT) (async/await)
    private func loadRequestDotsAsync(forMonthContaining date: Date) async {
        guard let uid = currentTechUID else { return }

        let techRef = db.collection("technicians").document(uid)
        let cal = Calendar.current

        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: date))!
        let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)!

        do {
            let snap = try await db.collection("requests")
                .whereField("assignedTechnician", isEqualTo: techRef)
                .whereField("assignedAt", isGreaterThanOrEqualTo: Timestamp(date: monthStart))
                .whereField("assignedAt", isLessThan: Timestamp(date: monthEnd))
                .getDocuments()

            let docs = snap.documents
            var days: [Date] = []
            for d in docs {
                if let ts = d.data()["assignedAt"] as? Timestamp {
                    days.append(cal.startOfDay(for: ts.dateValue()))
                }
            }

            // unique days
            self.requestDates = Array(Set(days))

            // UI update on main thread
            await MainActor.run {
                self.datePicker.reloadData()
            }
        } catch {
            print(" loadRequestDots error:", error)
        }
    }

    // MARK: - Data + Rendering (async/await)
    private func loadAndRenderAsync(for date: Date) async {
        // stop old listener + task
        listener?.remove()
        listener = nil
        listenTask?.cancel()
        listenTask = nil

        clearGeneratedCards()

        guard let uid = currentTechUID else { return }
        let techRef = db.collection("technicians").document(uid)

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!

        let q = db.collection("requests")
            .whereField("assignedTechnician", isEqualTo: techRef)
            .whereField("assignedAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("assignedAt", isLessThan: Timestamp(date: endOfDay))
            .order(by: "assignedAt", descending: false)

        // consume snapshots via async stream
        let stream = makeSnapshotStream(for: q)

        listenTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await snap in stream {
                    let docs = snap.documents
                    self.allDocs = docs.map { ($0.documentID, $0.data()) }

                    //  DO NOT set requestDates here anymore (this query is only 1 day)
                    // Dots are loaded by loadRequestDotsAsync(forMonthContaining:)

                    await MainActor.run {
                        self.applySearchAndRender(for: date)
                    }
                }
            } catch {
                print(" TechnSchedule query error:", error)
            }
        }
    }

    //  Wrap addSnapshotListener into AsyncThrowingStream (Swift 6 safe)
    private func makeSnapshotStream(for query: Query) -> AsyncThrowingStream<QuerySnapshot, Error> {

        // Actor to safely hold & mutate the registration across @Sendable closures
        actor RegistrationStore {
            private var reg: ListenerRegistration?

            func set(_ newReg: ListenerRegistration?) {
                reg = newReg
            }

            func remove() {
                reg?.remove()
                reg = nil
            }
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

            // Store registration safely
            Task { await store.set(reg) }

            // Remove safely when stream terminates
            continuation.onTermination = { _ in
                Task { await store.remove() }
            }
        }
    }


    private func applySearchAndRender(for selectedDate: Date) {
        clearGeneratedCards()

        let term = (searchBar.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let cal = Calendar.current
        let startOfSelectedDay = cal.startOfDay(for: selectedDate)

        // Filter by date (safe even if allDocs already day-filtered)
        var docsForDate = allDocs.filter { pair in
            guard
                let ts = pair.data["assignedAt"] as? Timestamp,
                let status = (pair.data["status"] as? String)?.lowercased()
            else { return false }

            let taskDay = cal.startOfDay(for: ts.dateValue())
            let allowedStatus = status == "accepted" || status == "begin"

            return taskDay == startOfSelectedDay && allowedStatus
        }

        // Filter by search term if any
        if !term.isEmpty {
            docsForDate = docsForDate.filter { pair in
                let data = pair.data
                let title = ((data["title"] as? String) ?? (data["problemTitle"] as? String) ?? "").lowercased()
                let loc = readLocationString(data).lowercased()
                let selectedPriorityLevel = ((data["selectedPriorityLevel"] as? String) ?? "").lowercased()

                return title.contains(term)
                    || loc.contains(term)
                    || selectedPriorityLevel.contains(term)
            }
        }

        filteredDocs = docsForDate

        if filteredDocs.isEmpty {
            showEmptyStateCard(message: term.isEmpty ? "No tasks found" : "No results for \"\(searchBar.text ?? "")\"")
            print("Filtered docs for date \(selectedDate):", filteredDocs.map { $0.data })
            return
        }

        for item in filteredDocs {
            addCard(for: item.data, docID: item.id)
        }
    }

    // MARK: - FSCalendarDataSource
    func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
        return requestDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: date) }) ? 1 : 0
    }

    // MARK: - FSCalendarDelegate
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        let normalized = Calendar.current.startOfDay(for: date)
        selectedDate = normalized

        tasksForLabel.text = "Task On: \(formatHeaderDate(normalized))"
        searchBar.text = ""
        searchBar.resignFirstResponder()

        //  Query Firestore for the selected day (async/await)
        Task { [weak self] in
            guard let self else { return }
            await self.loadAndRenderAsync(for: normalized)
        }
    }

    //  When user swipes to a new month, refresh dots for that month (async/await)
    func calendarCurrentPageDidChange(_ calendar: FSCalendar) {
        Task { [weak self] in
            guard let self else { return }
            await self.loadRequestDotsAsync(forMonthContaining: calendar.currentPage)
        }
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

    // MARK: - Card Rendering
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
            print(" templateCard is nil in addCard")
            return
        }
        guard let card = cloneView(template) else {
            print(" cloneView returned nil")
            return
        }
        
        applyCardCornerRadius(card)

        //  FORCE interaction
        card.isUserInteractionEnabled = true
        card.translatesAutoresizingMaskIntoConstraints = false

        let title = (data["title"] as? String) ?? (data["problemTitle"] as? String) ?? "Request"
        setLabelText(in: card, atIndex: 0, text: "\(title):")

        let locationText = readLocationString(data)
        setLabelText(in: card, atIndex: 1, text: locationText)

        let priorityRaw = (data["selectedPriorityLevel"] as? String) ?? "normal"
        let priorityText = "Priority: \(priorityRaw)"
        setLabelText(in: card, atIndex: 2, text: priorityText)

        applyPriorityColor(in: card, priority: priorityRaw)

        let createdText = formatDateFromAnyKnownField(data)
        setLabelText(in: card, atIndex: 3, text: createdText.isEmpty ? "" : "Created: \(createdText)")

        //button config for pages switch
        if let button = findFirstButton(in: card) {
            let status = (data["status"] as? String)?.lowercased() ?? "unknown"

            //  FORCE BUTTON TO RECEIVE TOUCHES
            button.isUserInteractionEnabled = true
            button.isEnabled = true
            button.alpha = 1.0

            // Debug (you WILL see this)
            print(" Button wired for request:", docID, "status:", status)

            button.accessibilityIdentifier = docID
            button.accessibilityHint = status

            button.removeTarget(nil, action: nil, for: .allEvents)
            button.addTarget(self,
                             action: #selector(openTaskDetails(_:)),
                             for: .touchUpInside)
        } else {
            print(" No button found in card")
        }

        card.isHidden = false
        requestsStackView.addArrangedSubview(card)
    }

    @objc private func openTaskDetails(_ sender: UIButton) {
        print(" BUTTON TAP DETECTED")
        guard
            let requestId = sender.accessibilityIdentifier,
            let status = sender.accessibilityHint?.lowercased()
        else { return }

        print("➡️ Opening task:", requestId, "status:", status)

        let sb = storyboard ?? UIStoryboard(name: "Main", bundle: nil)

        if status == "accepted" {
            guard let vc = sb.instantiateViewController(
                withIdentifier: "TechViewRequestViewController"
            ) as? TechViewRequestViewController else {
                print(" Could not instantiate TechViewRequestViewController")
                return
            }

            vc.requestId = requestId
            if let nav = navigationController {
                nav.pushViewController(vc, animated: true)
            } else {
                vc.modalPresentationStyle = .fullScreen
                present(vc, animated: true)
            }
        } else if status == "begin" {
            guard let vc = sb.instantiateViewController(
                withIdentifier: "TechnicianTaskFlowViewController"
            ) as? TechnicianTaskFlowViewController else {
                print(" Could not instantiate TechBeginTaskViewController")
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
            print(" cloneView failed:", error)
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

private func applyCardCornerRadius(_ card: UIView) {
    card.layer.cornerRadius = 10
    card.layer.masksToBounds = true   // or: card.clipsToBounds = true
}

