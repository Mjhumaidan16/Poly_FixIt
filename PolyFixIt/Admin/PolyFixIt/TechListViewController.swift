//
//  TechListViewController.swift
//  SignIn
//
//  Reused + updated for Technician Dashboard storyboard:
//  - Top counters: total technicians, currently free, currently busy, ongoing tasks, upcoming tasks
//  - List in stack view: tap busy -> schedule screen, tap free -> assignment screen
//  - Filters: search + segmented (All / Free / Busy)
//  - Busy/free derived from `requests` collection by matching `assignedTechnician` document reference
//

import UIKit
import FirebaseFirestore

final class TechListViewController: UIViewController {

    // MARK: - Firestored
    private let db = Firestore.firestore()

    // MARK: - Navigation (Storyboard IDs)
    // Update these to match your storyboard IDs.
    private let scheduleStoryboardID = "TechnScheduleViewController"
    private let assignStoryboardID   = "AdminTaskSelectionViewController"

    // MARK: - UI (found dynamically from storyboard)
    @IBOutlet weak var techniciansStackView: UIStackView?
    @IBOutlet weak var templateCardBusy: UIView?
    @IBOutlet weak var templateCardFree: UIView?

    @IBOutlet weak var segmentedControl: UISegmentedControl?
    @IBOutlet weak var searchBar: UISearchBar?

    // Metric value labels (numbers)
    @IBOutlet weak var totalTechValueLabel: UILabel?
    @IBOutlet weak var freeValueLabel: UILabel?
    @IBOutlet weak var busyValueLabel: UILabel?
    @IBOutlet weak var ongoingValueLabel: UILabel?
    @IBOutlet weak var upcomingValueLabel: UILabel?
    @IBOutlet weak var modificationButton: UIButton!

    private var generatedCards: [UIView] = []

    // MARK: - Data
    private var renderToken = UUID()

    private struct TechnicianVM {
        let uid: String
        let fullName: String
        let department: String
        let isActive: Bool

        // Derived from requests
        let isBusy: Bool
        let activeAssignedCount: Int
        let ongoingTitle: String?
        let upcomingTitle: String?
    }

    private var allTech: [TechnicianVM] = []
    private var filteredTech: [TechnicianVM] = []
    
    // MARK: - need to be changed for technician acount modidification
    @IBAction func modififcationButtonTapped(_ sender: UIButton) {

           let sb = self.storyboard ?? UIStoryboard(name: "Main", bundle: nil)
           guard let editVC = sb.instantiateViewController(withIdentifier: "PendingRequestsViewController")
                   as? PendingRequestsViewController else {
               print("❌ Could not instantiate PendingRequestsViewController. Check Storyboard ID + Custom Class.")
               return
           }


           if let nav = self.navigationController {
               nav.pushViewController(editVC, animated: true)
           } else {
               editVC.modalPresentationStyle = .fullScreen
               self.present(editVC, animated: true)
           }
       }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        wireDashboardControlsIfNeeded()
        loadAndRender()
    }
}

// MARK: - Load + Render
private extension TechListViewController {

    
    
     func extractTechnicianId(from data: [String: Any]) -> String? {
         if let ref = data["assignedTechnician"] as? DocumentReference {
             return ref.documentID
         }
         if let s = data["assignedTechnician"] as? String {
             return s
         }
         if let s = data["assignedTechnicianId"] as? String { // optional support
             return s
         }
         return nil
     }

 
     func isOpenRequest(_ data: [String: Any]) -> Bool {
         let completion = data["completionTime"]
         return completion == nil || completion is NSNull
     }

     func normalizedStatus(_ data: [String: Any]) -> String {
         return ((data["status"] as? String) ?? "")
             .trimmingCharacters(in: .whitespacesAndNewlines)
             .lowercased()
     }

    func loadAndRender() {
        let myToken = UUID()
        renderToken = myToken

        // Find UI anchors
        guard let stack = findTechniciansStackView() else {
            print("❌ Could not find technicians stack view.")
            return
        }
        techniciansStackView = stack

        // Use the two storyboard outlets if connected; otherwise discover from stack
        if templateCardBusy == nil || templateCardFree == nil {
            let pair = findTemplateCards(in: stack)
            templateCardBusy = templateCardBusy ?? pair.busy
            templateCardFree = templateCardFree ?? pair.free
        }

        guard let busyTemplate = templateCardBusy,
              let freeTemplate = templateCardFree else {
            print("❌ Could not find BOTH template cards (busy + free) inside stack view.")
            return
        }

        busyTemplate.isHidden = true
        freeTemplate.isHidden = true

        // Clear previously generated cards (keep both templates)
        clearGeneratedCards(keepingTemplates: [busyTemplate, freeTemplate], in: stack)

        // Fetch technicians + open requests (completionTime == null) in parallel
        let group = DispatchGroup()

        var techDocs: [QueryDocumentSnapshot] = []
        var openRequestDocs: [QueryDocumentSnapshot] = []
        var techError: Error?
        var reqError: Error?

        group.enter()
        db.collection("technicians").getDocuments { snapshot, error in
            techDocs = snapshot?.documents ?? []
            techError = error
            group.leave()
        }
/*
        group.enter()
        db.collection("requests")
            .whereField("completionTime", isEqualTo: NSNull()) // "open" (not completed)
            .getDocuments { snapshot, error in
                openRequestDocs = snapshot?.documents ?? []
                reqError = error
                group.leave()
            }
        */
        group.enter()
         
              db.collection("requests").getDocuments { snapshot, error in
                  openRequestDocs = snapshot?.documents ?? []
                  reqError = error
                  group.leave()
              }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            guard self.renderToken == myToken else { return }

            if let techError {
                print("❌ Firestore technicians error:", techError)
                return
            }
            if let reqError {
                print("❌ Firestore requests error:", reqError)
                return
            }

            
    
            let openRequestDocs = openRequestDocs.filter { doc in
                self.isOpenRequest(doc.data())
            }

            
            // Build request map by technician *ID* (doc id), not by full path
            let assignedOpen = openRequestDocs.compactMap { doc -> (techId: String, title: String)? in
                let data = doc.data()

                let status = (data["status"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() ?? ""

                guard status == "accepted" else { return nil }
                guard data["acceptanceTime"] as? Timestamp != nil else { return nil }
                guard let techRef = data["assignedTechnician"] as? DocumentReference else { return nil }

                print("assignedTechnician ref path:", techRef.path, "docID:", techRef.documentID)

                let title = (data["title"] as? String) ?? "Untitled"
                return (techRef.documentID, title)
            }

            var openByTechId: [String: [String]] = [:]
            for item in assignedOpen {
                openByTechId[item.techId, default: []].append(item.title)
            }

            // Prepare technicians list
            let techVMs: [TechnicianVM] = techDocs.map { doc in
                let data = doc.data()
                let uid = doc.documentID

                let fullName = (data["fullName"] as? String) ?? "Unknown"
                let department = (data["Department"] as? String) ?? "—"
                let isActive = (data["isActive"] as? Bool) ?? true

             
                let openTasks = openByTechId[uid] ?? []

                let isBusy = !openTasks.isEmpty
                let activeAssignedCount = openTasks.count

                // Titles (optional UI)
                let ongoingTitle = openTasks.first
                let upcomingTitle: String? = nil   // not tracked per-tech yet

                return TechnicianVM(
                    uid: uid,
                    fullName: fullName,
                    department: department,
                    isActive: isActive,
                    isBusy: isBusy,
                    activeAssignedCount: activeAssignedCount,
                    ongoingTitle: ongoingTitle,
                    upcomingTitle: upcomingTitle
                )
            }
            .sorted {
                $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
            }


            self.allTech = techVMs
            self.applyFiltersAndRender()
            self.updateTopCounters(from: techVMs, openRequestDocs: openRequestDocs)
        }
    }

    func applyFiltersAndRender() {
        let searchText = (searchBar?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let segmentIndex = segmentedControl?.selectedSegmentIndex ?? 0 // 0 all, 1 free, 2 busy

        let base: [TechnicianVM] = allTech.filter { $0.isActive } // show active only

        let byStatus: [TechnicianVM] = base.filter { vm in
            switch segmentIndex {
            case 1: return vm.isBusy == false
            case 2: return vm.isBusy == true
            default: return true
            }
        }

        if searchText.isEmpty {
            filteredTech = byStatus
        } else {
            let needle = searchText.lowercased()
            filteredTech = byStatus.filter { vm in
                vm.fullName.lowercased().contains(needle) ||
                vm.department.lowercased().contains(needle) ||
                vm.uid.lowercased().contains(needle)
            }
        }

        renderCards(filteredTech)
    }

    private func renderCards(_ list: [TechnicianVM]) {
        guard let stack = techniciansStackView,
              let busyTemplate = templateCardBusy,
              let freeTemplate = templateCardFree else { return }

        clearGeneratedCards(keepingTemplates: [busyTemplate, freeTemplate], in: stack)

        for (index, vm) in list.enumerated() {
            let templateToClone = vm.isBusy ? busyTemplate : freeTemplate
            guard let card = templateToClone.cloneView() else { continue }

            card.isHidden = false
            card.tag = 0

            configureTechCard(card, vm: vm, number: index + 1)
            stack.addArrangedSubview(card)
        }
    }

    func clearGeneratedCards(keepingTemplates templates: [UIView], in stack: UIStackView) {
        for v in stack.arrangedSubviews {
            if templates.contains(where: { $0 === v }) { continue }
            stack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
    }
}

// MARK: - UI Wiring (search + segmented + counters)
extension TechListViewController {

    func wireDashboardControlsIfNeeded() {
        // segmented
        if let seg: UISegmentedControl = view.findSubview(ofType: UISegmentedControl.self) {
            segmentedControl = seg
            seg.removeTarget(self, action: #selector(handleSegmentChanged(_:)), for: .valueChanged)
            seg.addTarget(self, action: #selector(handleSegmentChanged(_:)), for: .valueChanged)
        }

        // search bar
        if let sb: UISearchBar = view.findSubview(ofType: UISearchBar.self) {
            searchBar = sb
            sb.delegate = self
            sb.autocapitalizationType = .none
        }

        // metric value labels (found by title labels)
        totalTechValueLabel = findMetricValueLabel(titleText: "Total Technician")
        freeValueLabel = findMetricValueLabel(titleText: "Currently Free")
        busyValueLabel = findMetricValueLabel(titleText: "Currently Busy")
        ongoingValueLabel = findMetricValueLabel(titleText: "Ongoing Tasks")
        upcomingValueLabel = findMetricValueLabel(titleText: "Upcoming Tasks")
    }

    func findMetricValueLabel(titleText: String) -> UILabel? {
        // Find the title label first
        guard let titleLabel = view.findSubview(ofType: UILabel.self, where: { $0.text == titleText }) else {
            return nil
        }
        // In that container view, the other label is the value
        let container = titleLabel.superview
        let siblings = container?.subviews.compactMap { $0 as? UILabel } ?? []
        return siblings.first(where: { $0 !== titleLabel })
    }

    @objc func handleSegmentChanged(_ sender: UISegmentedControl) {
        applyFiltersAndRender()
    }

    private func updateTopCounters(from techVMs: [TechListViewController.TechnicianVM],
                                      openRequestDocs: [QueryDocumentSnapshot]) {
        let activeTechs = techVMs.filter { $0.isActive }
        let totalTech = activeTechs.count
        let busyTech = activeTechs.filter { $0.isBusy }.count
        let freeTech = activeTechs.filter { !$0.isBusy }.count

        // Only "accepted" requests count toward ongoing/upcoming
        // Ongoing  = accepted + assignedTechnician != nil
        // Upcoming = accepted + assignedTechnician == nil
        var ongoing = 0
        var upcoming = 0

        for doc in openRequestDocs {
            let data = doc.data()

            // status must be accepted
            let status = (data["status"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""
            guard status == "accepted" else { continue }

            let assigned = data["assignedTechnician"] as? DocumentReference
            if assigned != nil {
                ongoing += 1
            } else {
                upcoming += 1
            }
        }

        totalTechValueLabel?.text = "\(totalTech)"
        freeValueLabel?.text = "\(freeTech)"
        busyValueLabel?.text = "\(busyTech)"
        ongoingValueLabel?.text = "\(ongoing)"
        upcomingValueLabel?.text = "\(upcoming)"
    }
}

// MARK: - Card Configuration + Navigation
private extension TechListViewController {

    func findTechniciansStackView() -> UIStackView? {
        // Prefer the vertical stack view that contains a "card-like" subview with 112 height constraint
        // (matches your storyboard cards)
        return view.findSubview(ofType: UIStackView.self) { stack in
            guard stack.axis == .vertical else { return false }
            return stack.arrangedSubviews.contains(where: { v in
                // heuristic: has a big name label (21pt)
                v.findSubview(ofType: UILabel.self, where: { abs($0.font.pointSize - 21) < 0.5 }) != nil
            })
        }
    }

    func findTemplateCards(in stack: UIStackView) -> (busy: UIView?, free: UIView?) {
        // Prefer explicit tags if you set them (recommended):
        // busy template tag = 2, free template tag = 1
        let busyByTag = stack.arrangedSubviews.first(where: { $0.tag == 2 })
        let freeByTag = stack.arrangedSubviews.first(where: { $0.tag == 1 })

        if busyByTag != nil || freeByTag != nil {
            return (busyByTag, freeByTag)
        }

        // Fallback: first two arranged subviews
        let views = stack.arrangedSubviews
        if views.count >= 2 {
            return (views[0], views[1])
        } else if views.count == 1 {
            return (views[0], nil)
        } else {
            return (nil, nil)
        }
    }

    private func configureTechCard(_ card: UIView, vm: TechnicianVM, number: Int) {
        let nameLabel = card.findSubview(ofType: UILabel.self, where: { abs($0.font.pointSize - 21) < 0.5 })
        let idLabel = card.findSubview(ofType: UILabel.self, where: { ($0.text ?? "").lowercased().hasPrefix("id:") })
        let statusLabel = findStatusBadgeLabel(in: card)
        let deptLabel = findDepartmentLabel(in: card)
        let tasksAssignedLabel = card.findSubview(ofType: UILabel.self, where: { label in
            let t = (label.text ?? "").lowercased()
            return t.contains("tasks") && t.contains("assigned")
        })
        tasksAssignedLabel?.text = "\(vm.activeAssignedCount) Tasks Assigned"

        let detailLabel = card.findSubview(ofType: UILabel.self, where: { ($0.text ?? "").localizedCaseInsensitiveContains("Ongoing:") || ($0.text ?? "").localizedCaseInsensitiveContains("Upcoming:") })

        // Arrow button
        let arrowButton = findArrowButton(in: card)

        nameLabel?.text = vm.fullName
        idLabel?.text = "ID: \(vm.uid)"
        deptLabel?.text = vm.department

        // Status
        statusLabel?.text = vm.isBusy ? "Busy" : "Free"

        // Assigned tasks count (active assigned)
        tasksAssignedLabel?.text = "\(vm.activeAssignedCount) Tasks Assigned"

        // Detail line (prefer ongoing, else upcoming, else empty)
        if let ongoing = vm.ongoingTitle {
            detailLabel?.text = "Ongoing: \(ongoing)"
        } else if let upcoming = vm.upcomingTitle {
            detailLabel?.text = "Upcoming: \(upcoming)"
        } else {
            detailLabel?.text = ""
        }

        // Tap handling (arrow button + whole card)
        arrowButton?.accessibilityIdentifier = vm.uid
        arrowButton?.removeTarget(self, action: #selector(handleCardTapped(_:)), for: .touchUpInside)
        arrowButton?.addTarget(self, action: #selector(handleCardTapped(_:)), for: .touchUpInside)

        // Whole card tap
        card.isUserInteractionEnabled = true
        card.gestureRecognizers?.forEach { card.removeGestureRecognizer($0) }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleCardTapGesture(_:)))
        tap.cancelsTouchesInView = false
        card.addGestureRecognizer(tap)
        card.accessibilityIdentifier = vm.uid

        // Store status in tag so we can decide navigation fast
        card.tag = vm.isBusy ? 2 : 1 // 2 busy, 1 free
    }

    func findDepartmentLabel(in card: UIView) -> UILabel? {
        // Dept label is 12pt and NOT ID, NOT Tasks, NOT status badge (11pt)
        let labels = card.allSubviews.compactMap { $0 as? UILabel }
        let cands = labels.filter { abs($0.font.pointSize - 12) < 0.5 }
        return cands.first(where: { lbl in
            let t = (lbl.text ?? "").lowercased()
            return !t.hasPrefix("id:") && !t.contains("tasks assigned") && !t.contains("ongoing:") && !t.contains("upcoming:")
        })
    }

    func findStatusBadgeLabel(in card: UIView) -> UILabel? {
        // Status badge in storyboard is 11pt and says "Busy"/"Free"
        let labels = card.allSubviews.compactMap { $0 as? UILabel }
        let cands = labels.filter { abs($0.font.pointSize - 11) < 0.5 }
        return cands.first
    }

    func findArrowButton(in card: UIView) -> UIButton? {
        let buttons = card.allSubviews.compactMap { $0 as? UIButton }
        // Heuristic: configuration image is system "arrow.forward"
        if let b = buttons.first(where: { $0.configuration?.image?.accessibilityIdentifier == "arrow.forward" }) {
            return b
        }
        // Fallback: any button with SF symbol name "arrow.forward" in current image
        return buttons.first(where: { button in
            if let img = button.configuration?.image { return img.isSymbolImage }
            if let img = button.image(for: .normal) { return img.isSymbolImage }
            return false
        })
    }

    @objc func handleCardTapGesture(_ gr: UITapGestureRecognizer) {
        guard let card = gr.view else { return }
        let uid = card.accessibilityIdentifier ?? ""
        if uid.isEmpty { return }
        navigateForTechnician(uid: uid)
    }

    @objc func handleCardTapped(_ sender: UIButton) {
        guard let uid = sender.accessibilityIdentifier, !uid.isEmpty else { return }
        navigateForTechnician(uid: uid)
    }

    func navigateForTechnician(uid: String) {
        guard let vm = allTech.first(where: { $0.uid == uid }) else { return }
        
        let sb = self.storyboard ?? UIStoryboard(name: "Main", bundle: nil)
        
        if vm.isBusy {
            guard let scheduleVC = sb.instantiateViewController(withIdentifier: scheduleStoryboardID) as? TechnScheduleViewController else {
                showSimpleAlert(title: "Missing Screen", message: "Could not open schedule screen. Check storyboard ID: \(scheduleStoryboardID)")
                return
            }
            
            // ✅ PASS DATA
            scheduleVC.technicianUID = vm.uid
            scheduleVC.technicianFullName = vm.fullName
            
            pushOrPresent(scheduleVC)
        } else {
            // Technician is free -> go to assignment screen and PASS DATA
            guard let assignVC = sb.instantiateViewController(withIdentifier: assignStoryboardID) as? AdminTaskSelectionViewController else {
                showSimpleAlert(title: "Missing Screen",
                                message: "Could not open assignment screen. Check storyboard ID: \(assignStoryboardID)")
                return
            }
            
            // ✅ PASS DATA
            assignVC.technicianUID = vm.uid
            
            pushOrPresent(assignVC)
        }
    }


    func pushOrPresent(_ vc: UIViewController) {
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
    }

    func showSimpleAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}



// MARK: - UISearchBarDelegate
extension TechListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFiltersAndRender()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        applyFiltersAndRender()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        applyFiltersAndRender()
    }
}

// MARK: - UIView helpers
private extension UIView {

    func cloneView() -> UIView? {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
            return try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? UIView
        } catch {
            print("❌ Clone view failed:", error)
            return nil
        }
    }

    func findSubview<T: UIView>(ofType: T.Type, where predicate: ((T) -> Bool)? = nil) -> T? {
        if let v = self as? T, predicate?(v) ?? true { return v }
        for sub in subviews {
            if let match: T = sub.findSubview(ofType: T.self, where: predicate) { return match }
        }
        return nil
    }

    var allSubviews: [UIView] {
        subviews + subviews.flatMap { $0.allSubviews }
    }
}
