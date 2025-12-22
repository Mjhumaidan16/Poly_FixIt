//
//  RoomAvailability.swift
//  SignIn
//
//  Campus -> Building -> Class picker + Week/Day navigator + Availability slots renderer.
//
//  IMPORTANT UI IDEA:
//  - Your storyboard contains ONE vertical UIStackView (the container).
//  - We dynamically create as many "slot cards" as Firestore returns (1..N).
//  - No more pre-building/hiding 10 views in storyboard.
//

import UIKit
import FirebaseFirestore

final class LocationPickerViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    // MARK: - Outlets
    @IBOutlet weak var locationPickerView: UIPickerView!

    // Week/Day UI Outlets (connected in storyboard)
    @IBOutlet weak var weekLabel: UILabel?
    @IBOutlet weak var dayLabel: UILabel?
    @IBOutlet weak var leftArrowButton: UIButton?
    @IBOutlet weak var rightArrowButton: UIButton?

    /// Connect this to the vertical UIStackView that should hold the availability cards.
    @IBOutlet weak var slotsStackView: UIStackView?

    // MARK: - Firestore
    private let db = Firestore.firestore()

    // MARK: - Data (same structure)
    private let buildingsByCampus: [String: [String]] = [
        "campA": ["19", "36", "25"],
        "campB": ["20", "25"]
    ]

    private let classesByBuilding: [String: [String]] = [
        "19": ["01", "02", "03", "04"],
        "36": ["101", "102", "103", "104"],
        "25": ["313", "314", "315", "316"],
        "20": ["98", "99", "100", "101"]
    ]

    // MARK: - Runtime picker data
    private var campuses: [String] = []
    private var buildings: [String] = []
    private var classes: [String] = []

    // MARK: - Current Selection
    private(set) var selectedCampus: String?
    private(set) var selectedBuilding: String?
    private(set) var selectedClass: String?

    /// e.g. "A-36-102"
    var compactLocationString: String {
        let campusCode = campusLetter(from: selectedCampus)
        let b = selectedBuilding ?? ""
        let r = selectedClass ?? ""
        return "\(campusCode)-\(b)-\(r)"
    }

    // MARK: - Week/Day
    private let daysOfWeek: [String] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private let minWeek: Int = 0
    private let maxWeek: Int = 12

    private var currentWeek: Int = 0
    private var currentDayIndex: Int = 0 // 0=Sun ... 6=Sat

    // Reference you gave:
    // Week 0 Sat = 3 January 2026
    private let week0SaturdayReference: Date = {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 1
        comps.day = 3
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        return Calendar.current.date(from: comps) ?? Date()
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        locationPickerView.delegate = self
        locationPickerView.dataSource = self

        campuses = Array(buildingsByCampus.keys).sorted()
        selectedCampus = campuses.first

        reloadBuildingsAndClasses()

        locationPickerView.reloadAllComponents()
        locationPickerView.selectRow(0, inComponent: 0, animated: false)
        locationPickerView.selectRow(0, inComponent: 1, animated: false)
        locationPickerView.selectRow(0, inComponent: 2, animated: false)

        updateWeekDayUI()
        clearSlotViews() // Start with an empty list

        updatePreview()
    }

    // MARK: - Week/Day Actions
    @IBAction func leftArrowTapped(_ sender: UIButton) {
        if currentDayIndex == 0 {
            // Sun -> Sat of previous week
            if currentWeek > minWeek {
                currentWeek -= 1
                currentDayIndex = 6
            } else {
                // Clamp
                currentWeek = minWeek
                currentDayIndex = 0
            }
        } else {
            currentDayIndex -= 1
        }
        updateWeekDayUI()
    }

    @IBAction func rightArrowTapped(_ sender: UIButton) {
        if currentDayIndex == 6 {
            // Sat -> Sun of next week
            if currentWeek < maxWeek {
                currentWeek += 1
                currentDayIndex = 0
            } else {
                // Clamp
                currentWeek = maxWeek
                currentDayIndex = 6
            }
        } else {
            currentDayIndex += 1
        }
        updateWeekDayUI()
    }

    private func updateWeekDayUI() {
        weekLabel?.text = "Week \(currentWeek)"
        dayLabel?.text = daysOfWeek.indices.contains(currentDayIndex) ? daysOfWeek[currentDayIndex] : ""

        leftArrowButton?.isEnabled = !(currentWeek == minWeek && currentDayIndex == 0)
        rightArrowButton?.isEnabled = !(currentWeek == maxWeek && currentDayIndex == 6)
    }

    // MARK: - "Check Availability" button
    /// Connected to the "Check Availability" button in storyboard.
    @IBAction func fetchAvailabilityButtonTapped(_ sender: UIButton) {
        fetchAvailabilityForSelectedLocationAndDay()
    }

    // MARK: - Firestore Fetch
    private func fetchAvailabilityForSelectedLocationAndDay() {
        let docId = compactLocationString
        if docId.isEmpty {
            print("❌ compactLocationString is empty")
            clearSlotViews()
            return
        }

        // Calculate the exact day from Week + Day
        let selectedDate = getSelectedDateFromWeekAndDay()
        let dayStart = Calendar.current.startOfDay(for: selectedDate)
        guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else {
            print("❌ Could not compute day end")
            clearSlotViews()
            return
        }

        // Fetch: roomAvailability/{A-36-101}
        let docRef = db.collection("roomAvailability").document(docId)

        docRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ Firestore fetch error: \(error.localizedDescription)")
                DispatchQueue.main.async { self.renderEmptyState("Error fetching availability") }
                return
            }

            guard let snapshot = snapshot, snapshot.exists else {
                print("ℹ️ No document for \(docId)")
                DispatchQueue.main.async { self.renderEmptyState("No availability") }
                return
            }

            let data = snapshot.data() ?? [:]
            let starts = data["startTime"] as? [Timestamp] ?? []
            let ends   = data["endTime"] as? [Timestamp] ?? []

            let count = min(starts.count, ends.count)
            if count == 0 {
                DispatchQueue.main.async { self.renderEmptyState("No availability") }
                return
            }

            // Pair times by index (start[i] matches end[i])
            var intervals: [(start: Date, end: Date)] = []
            intervals.reserveCapacity(count)
            for i in 0..<count {
                let s = starts[i].dateValue()
                let e = ends[i].dateValue()
                if e > s {
                    intervals.append((start: s, end: e))
                }
            }

            // Filter to the selected day.
            // NOTE: Your data is saved as full timestamps (date + time).
            // This filter keeps slots that START within that day.
            let filtered = intervals
                .filter { $0.start >= dayStart && $0.start < dayEnd }
                .sorted { $0.start < $1.start }

            DispatchQueue.main.async {
                self.renderSlots(filtered)
            }
        }
    }

    // MARK: - Dynamic Stack Rendering
    private func clearSlotViews() {
        guard let stack = slotsStackView else { return }
        for v in stack.arrangedSubviews {
            stack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
    }

    private func renderEmptyState(_ message: String) {
        clearSlotViews()
        guard let stack = slotsStackView else { return }

        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)

        stack.addArrangedSubview(label)
    }

    private func renderSlots(_ slots: [(start: Date, end: Date)]) {
        clearSlotViews()

        guard let stack = slotsStackView else {
            print("❌ slotsStackView outlet not connected")
            return
        }

        guard !slots.isEmpty else {
            renderEmptyState("No slots for this day")
            return
        }

        // Formatters
        let startOnlyFormatter = DateFormatter()
        startOnlyFormatter.locale = Locale.current
        startOnlyFormatter.timeZone = TimeZone.current
        startOnlyFormatter.dateFormat = "h:mm\na" // 9:00\nAM

        let rangeFormatter = DateFormatter()
        rangeFormatter.locale = Locale.current
        rangeFormatter.timeZone = TimeZone.current
        rangeFormatter.dateFormat = "h:mm a" // 9:00 AM

        for slot in slots {
            let startText = startOnlyFormatter.string(from: slot.start)
            let startRange = rangeFormatter.string(from: slot.start)
            let endRange = rangeFormatter.string(from: slot.end)

            let hours = slot.end.timeIntervalSince(slot.start) / 3600.0
            let hoursText = String(format: "%.1f Hours Available Slot", hours)

            let card = AvailabilitySlotView()
            card.configure(
                startText: startText,
                rangeText: "\(startRange) - \(endRange)",
                hoursText: hoursText
            )
            stack.addArrangedSubview(card)
        }
    }

    // MARK: - Date calculation from (week, dayIndex)
    private func getSelectedDateFromWeekAndDay() -> Date {
        // base is Week 0 Sat (dayIndex = 6)
        // offset days = (week * 7) + (dayIndex - 6)
        let offsetDays = (currentWeek * 7) + (currentDayIndex - 6)
        return Calendar.current.date(byAdding: .day, value: offsetDays, to: week0SaturdayReference) ?? week0SaturdayReference
    }

    // MARK: - UIPickerViewDataSource
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 3 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch component {
        case 0: return campuses.count
        case 1: return buildings.count
        case 2: return classes.count
        default: return 0
        }
    }

    // MARK: - UIPickerViewDelegate
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch component {
        case 0: return campuses.indices.contains(row) ? campuses[row] : nil
        case 1: return buildings.indices.contains(row) ? buildings[row] : nil
        case 2: return classes.indices.contains(row) ? classes[row] : nil
        default: return nil
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch component {
        case 0:
            guard campuses.indices.contains(row) else { return }
            selectedCampus = campuses[row]

            reloadBuildingsAndClasses()
            pickerView.reloadComponent(1)
            pickerView.reloadComponent(2)
            pickerView.selectRow(0, inComponent: 1, animated: true)
            pickerView.selectRow(0, inComponent: 2, animated: true)

        case 1:
            guard buildings.indices.contains(row) else { return }
            selectedBuilding = buildings[row]

            classes = classesByBuilding[selectedBuilding ?? ""] ?? []
            selectedClass = classes.first

            pickerView.reloadComponent(2)
            pickerView.selectRow(0, inComponent: 2, animated: true)

        case 2:
            guard classes.indices.contains(row) else { return }
            selectedClass = classes[row]

        default:
            break
        }

        updatePreview()
    }

    // MARK: - Helpers
    private func reloadBuildingsAndClasses() {
        buildings = buildingsByCampus[selectedCampus ?? ""] ?? []
        selectedBuilding = buildings.first

        classes = classesByBuilding[selectedBuilding ?? ""] ?? []
        selectedClass = classes.first
    }

    private func updatePreview() {
        print("Selected: \(compactLocationString)")
        print("Week/Day: Week \(currentWeek), \(daysOfWeek[currentDayIndex])")
        print("Selected Date:", getSelectedDateFromWeekAndDay())
    }

    private func campusLetter(from campus: String?) -> String {
        guard let campus = campus else { return "" }
        if campus.lowercased().contains("campa") { return "A" }
        if campus.lowercased().contains("campb") { return "B" }
        if let last = campus.last, last.isLetter { return String(last).uppercased() }
        return campus
    }
}
