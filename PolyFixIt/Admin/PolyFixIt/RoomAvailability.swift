//
//  LocationBackendViewController.swift
//  SignIn
//
//  Campus -> Building -> Class picker backend.
//
//  How to use:
//  1) Set your scene's custom class to `LocationBackendViewController`.
//  2) Add a UIPickerView and connect it to `locationPickerView`.
//  3) Read `selectedCampus`, `selectedBuilding`, `selectedClass` when you need.
//

import UIKit
import FirebaseFirestore

final class LocationBackendViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    // MARK: - Outlet
    @IBOutlet weak var locationPickerView: UIPickerView!

    // MARK: - Date & Time Outlets (connect later)
    /// Date (calendar) picker
    @IBOutlet weak var datePicker: UIDatePicker?
    /// Time-only picker for start time
    @IBOutlet weak var startTimePicker: UIDatePicker?
    /// Time-only picker for end time
    @IBOutlet weak var endTimePicker: UIDatePicker?

    // MARK: - Firestore
    private let db = Firestore.firestore()

    // MARK: - Data
    /// Campus -> Buildings
    private let buildingsByCampus: [String: [String]] = [
        "campusA": ["19", "36", "25"],
        "campusB": ["20", "25"]
    ]

    /// Building -> 4 Classes (edit names however you want)
    private let classesByBuilding: [String: [String]] = [
        "19": ["01", "02", "03", "04"],
        "36": ["101", "102", "103", "104"],
        "25": ["313", "314", "315", "316"],
        "20": ["98", "99", "100", "101"]
    ]

    // MARK: - State
    private var campuses: [String] = []
    private var buildings: [String] = []
    private var classes: [String] = []

    /// Current selection (read-only from outside)
    private(set) var selectedCampus: String?
    private(set) var selectedBuilding: String?
    private(set) var selectedClass: String?

    // MARK: - Output variables (set when button is clicked)
    /// Combined Date + Start Time
    private(set) var startTime: Date?
    /// Combined Date + End Time
    private(set) var endTime: Date?
    /// Location formatted like: A-25-350
    private(set) var classLocation: String?

    /// Swift keyword workaround: this gives you a property literally named `class`.
    /// Use it if you want: `print(self.class ?? "")`
    var `class`: String? { classLocation }

    /// Optional callback if you want to react when selection changes.
    var onLocationChanged: ((_ campus: String?, _ building: String?, _ theClass: String?) -> Void)?

    // MARK: - Edit-confirmation logic
    private var saveIsAllowedToRun: Bool = false

    // ✅ NEW: if user taps "Proceed" on a fully-contained interval, we allow editing (shrinking) it
    private var allowContainedEdit: Bool = false

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

        notifyChange()
    }

    // MARK: - Button Action (connect later)
    /// Call this when user confirms date/time/location.
    @IBAction func confirmSelectionButtonTapped(_ sender: UIButton) {
        startTime = combine(date: datePicker?.date, time: startTimePicker?.date)
        endTime = combine(date: datePicker?.date, time: endTimePicker?.date)
        classLocation = getSelectedCompactLocationString()

        // Reset per-attempt flags
        saveIsAllowedToRun = false
        allowContainedEdit = false

        // ✅ IMPORTANT FIX:
        // Do NOT call _guardedSaveRoomAvailabilityCall() here.
        // The Firestore check is async, so saving must be triggered ONLY from inside the check callback
        // (either immediately if no alert is needed, or after user taps Proceed).
        checkIfNeedsEditConfirmationAndProceedIfAllowed()
    }

    // MARK: - Firestore Save Logic
    private func saveRoomAvailability() {
        guard let docId = classLocation, !docId.isEmpty else {
            print("❌ classLocation is nil/empty")
            return
        }
        guard let s = startTime, let e = endTime else {
            print("❌ startTime/endTime not set")
            return
        }
        if e <= s {
            print("❌ endTime must be after startTime")
            return
        }

        let docRef = db.collection("roomAvailability").document(docId)

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(docRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            let newStart = Timestamp(date: s)
            let newEnd   = Timestamp(date: e)

            struct Interval {
                var start: Timestamp
                var end: Timestamp
            }

            func tsToDate(_ ts: Timestamp) -> Date { ts.dateValue() }

            guard snapshot.exists else {
                transaction.setData([
                    "startTime": [newStart],
                    "endTime": [newEnd]
                ], forDocument: docRef)
                return "created"
            }

            let data = snapshot.data() ?? [:]
            let starts = data["startTime"] as? [Timestamp] ?? []
            let ends   = data["endTime"] as? [Timestamp] ?? []

            let count = min(starts.count, ends.count)
            var intervals: [Interval] = []
            intervals.reserveCapacity(count)
            for i in 0..<count {
                let st = starts[i]
                let en = ends[i]
                if tsToDate(en) > tsToDate(st) {
                    intervals.append(Interval(start: st, end: en))
                }
            }

            intervals.sort { tsToDate($0.start) < tsToDate($1.start) }

            var didContainedEdit = false

            for i in 0..<intervals.count {
                let existing = intervals[i]
                let exS = tsToDate(existing.start)
                let exE = tsToDate(existing.end)
                let ns  = tsToDate(newStart)
                let ne  = tsToDate(newEnd)

                let fullyContained = (ns >= exS) && (ne <= exE)
                if fullyContained {
                    if self.allowContainedEdit {
                        intervals[i] = Interval(start: newStart, end: newEnd)
                        didContainedEdit = true
                        break
                    } else {
                        let err = NSError(
                            domain: "RoomAvailability",
                            code: 409,
                            userInfo: [NSLocalizedDescriptionKey: "New time is inside an existing availability."]
                        )
                        errorPointer?.pointee = err
                        return nil
                    }
                }
            }

            var merged = Interval(start: newStart, end: newEnd)
            var didMerge = false

            func overlaps(_ a: Interval, _ b: Interval) -> Bool {
                let aS = tsToDate(a.start), aE = tsToDate(a.end)
                let bS = tsToDate(b.start), bE = tsToDate(b.end)
                return aS < bE && bS < aE
            }

            if !didContainedEdit {
                var remaining: [Interval] = []
                for ex in intervals {
                    if overlaps(ex, merged) {
                        didMerge = true
                        if tsToDate(ex.start) < tsToDate(merged.start) { merged.start = ex.start }
                        if tsToDate(ex.end)   > tsToDate(merged.end)   { merged.end   = ex.end }
                    } else {
                        remaining.append(ex)
                    }
                }

                var changed = true
                while changed {
                    changed = false
                    var newRemaining: [Interval] = []
                    for ex in remaining {
                        if overlaps(ex, merged) {
                            changed = true
                            didMerge = true
                            if tsToDate(ex.start) < tsToDate(merged.start) { merged.start = ex.start }
                            if tsToDate(ex.end)   > tsToDate(merged.end)   { merged.end   = ex.end }
                        } else {
                            newRemaining.append(ex)
                        }
                    }
                    remaining = newRemaining
                }

                remaining.append(merged)
                intervals = remaining
            }

            intervals.sort { tsToDate($0.start) < tsToDate($1.start) }

            let newStarts = intervals.map { $0.start }
            let newEnds   = intervals.map { $0.end }

            transaction.updateData([
                "startTime": newStarts,
                "endTime": newEnds
            ], forDocument: docRef)

            if didContainedEdit { return "edited" }
            if didMerge { return "merged" } else { return "appended" }

        }, completion: { result, error in
            if let error = error {
                print("❌ Save availability failed: \(error.localizedDescription)")
                return
            }
            if let status = result as? String {
                print("✅ Availability saved: \(status)")
            } else {
                print("✅ Availability saved")
            }

            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Success",
                    message: "Time has been recorded",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        })
    }

    // MARK: - Checks whether we should ask for “Proceed / No”
    private func checkIfNeedsEditConfirmationAndProceedIfAllowed() {
        guard let docId = classLocation, !docId.isEmpty else { saveIsAllowedToRun = true; _guardedSaveRoomAvailabilityCall(); return }
        guard let s = startTime, let e = endTime else { saveIsAllowedToRun = true; _guardedSaveRoomAvailabilityCall(); return }
        if e <= s { saveIsAllowedToRun = true; _guardedSaveRoomAvailabilityCall(); return }

        saveIsAllowedToRun = false
        allowContainedEdit = false

        let docRef = db.collection("roomAvailability").document(docId)

        docRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if error != nil {
                self.saveIsAllowedToRun = true
                self._guardedSaveRoomAvailabilityCall()
                return
            }
            guard let snapshot = snapshot, snapshot.exists else {
                self.saveIsAllowedToRun = true
                self._guardedSaveRoomAvailabilityCall()
                return
            }

            let data = snapshot.data() ?? [:]
            let starts = data["startTime"] as? [Timestamp] ?? []
            let ends   = data["endTime"] as? [Timestamp] ?? []

            let count = min(starts.count, ends.count)
            func tsToDate(_ ts: Timestamp) -> Date { ts.dateValue() }

            let newStart = s
            let newEnd = e

            var shouldAskProceed = false

            for i in 0..<count {
                let exS = tsToDate(starts[i])
                let exE = tsToDate(ends[i])
                if exE <= exS { continue }

                let overlaps = (exS < newEnd) && (newStart < exE)
                if !overlaps { continue }

                let fullyContained = (newStart >= exS) && (newEnd <= exE)
                if fullyContained {
                    shouldAskProceed = true
                    break
                }

                let expands = (newStart < exS) || (newEnd > exE)
                if expands {
                    shouldAskProceed = true
                    break
                }
            }

            if shouldAskProceed {
                self.presentProceedOrCancelAlert(
                    title: "Edit Availability?",
                    message: "This time overlaps an existing availability and will modify it. Do you want to proceed?",
                    proceedTitle: "Proceed",
                    cancelTitle: "No",
                    onProceed: {
                        self.allowContainedEdit = true
                        self.saveIsAllowedToRun = true
                        self._guardedSaveRoomAvailabilityCall()
                    },
                    onCancel: {
                        self.allowContainedEdit = false
                        self.saveIsAllowedToRun = false
                    }
                )
            } else {
                self.saveIsAllowedToRun = true
                self._guardedSaveRoomAvailabilityCall()
            }
        }
    }

    private func presentProceedOrCancelAlert(
        title: String,
        message: String,
        proceedTitle: String,
        cancelTitle: String,
        onProceed: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: { _ in onCancel() }))
            alert.addAction(UIAlertAction(title: proceedTitle, style: .default, handler: { _ in onProceed() }))
            self.present(alert, animated: true)
        }
    }

    private func _guardedSaveRoomAvailabilityCall() {
        if saveIsAllowedToRun {
            saveRoomAvailability()
        }
    }

    // MARK: - Public helpers
    func getSelectedLocationDictionary() -> [String: [String]] {
        return [
            "campus": [selectedCampus ?? ""],
            "building": [selectedBuilding ?? ""],
            "room": [selectedClass ?? ""]
        ]
    }

    func getSelectedLocationString() -> String {
        let c = selectedCampus ?? ""
        let b = selectedBuilding ?? ""
        let r = selectedClass ?? ""
        return "\(c) - \(b) - \(r)"
    }

    func getSelectedCompactLocationString() -> String {
        let campusCode = campusLetter(from: selectedCampus)
        let building = selectedBuilding ?? ""
        let theClass = selectedClass ?? ""
        return "\(campusCode)-\(building)-\(theClass)"
    }

    // MARK: - UIPickerViewDataSource
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 3
    }

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
        case 0:
            guard campuses.indices.contains(row) else { return nil }
            return campuses[row]
        case 1:
            guard buildings.indices.contains(row) else { return nil }
            return buildings[row]
        case 2:
            guard classes.indices.contains(row) else { return nil }
            return classes[row]
        default:
            return nil
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

        notifyChange()
    }

    // MARK: - Private
    private func reloadBuildingsAndClasses() {
        buildings = buildingsByCampus[selectedCampus ?? ""] ?? []
        selectedBuilding = buildings.first

        classes = classesByBuilding[selectedBuilding ?? ""] ?? []
        selectedClass = classes.first
    }

    private func notifyChange() {
        onLocationChanged?(selectedCampus, selectedBuilding, selectedClass)
        print("Location: \(getSelectedLocationString())")
    }

    private func campusLetter(from campus: String?) -> String {
        guard let campus = campus else { return "" }
        if campus.lowercased().contains("campusa") { return "A" }
        if campus.lowercased().contains("campusb") { return "B" }
        if let last = campus.last, last.isLetter { return String(last).uppercased() }
        return campus
    }

    private func combine(date: Date?, time: Date?) -> Date? {
        guard let date = date, let time = time else { return nil }
        let cal = Calendar.current
        let dateParts = cal.dateComponents([.year, .month, .day], from: date)
        let timeParts = cal.dateComponents([.hour, .minute, .second], from: time)

        var combined = DateComponents()
        combined.year = dateParts.year
        combined.month = dateParts.month
        combined.day = dateParts.day
        combined.hour = timeParts.hour
        combined.minute = timeParts.minute
        combined.second = timeParts.second

        return cal.date(from: combined)
    }
}
