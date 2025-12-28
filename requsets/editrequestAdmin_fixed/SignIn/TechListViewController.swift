//
//  TechListViewController.swift
//  SignIn
//
//  Created by BP-36-212-19 on 24/12/2025.
//

import UIKit
import FirebaseFirestore

final class TechListViewController: UIViewController {

    private let db = Firestore.firestore()

    // Connect storyboard "Refreash" button to this outlet
    @IBOutlet weak var refreshButton: UIButton!

    // Prevent duplicate renders when refresh is tapped multiple times quickly
    private var renderToken = UUID()

    override func viewDidLoad() {
        super.viewDidLoad()

        refreshButton.addTarget(self, action: #selector(handleRefreshTapped), for: .touchUpInside)
        loadTechniciansAndRender()
    }

    @objc private func handleRefreshTapped() {
        loadTechniciansAndRender()
    }

    // MARK: - Main render
    private func loadTechniciansAndRender() {
        let myToken = UUID()
        renderToken = myToken
        refreshButton.isEnabled = false

        guard let stackView = findTechStackView(),
              let templateCard = stackView.arrangedSubviews.first(where: { $0.tag == 1 }) else {
            print("❌ Could not find stackView or template card (tag=1).")
            refreshButton.isEnabled = true
            return
        }

        templateCard.isHidden = true

        // Clear previous generated cards
        for v in stackView.arrangedSubviews where v !== templateCard {
            stackView.removeArrangedSubview(v)
            v.removeFromSuperview()
        }

        // ✅ Fetch ALL technicians (active + inactive)
        db.collection("technicians").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            guard self.renderToken == myToken else { return }

            DispatchQueue.main.async {
                self.refreshButton.isEnabled = true
            }

            if let error = error {
                print("❌ Firestore error:", error)
                return
            }

            let docs = snapshot?.documents ?? []

            // Sort by createdAt if exists, else by fullName
            let sorted = docs.sorted { a, b in
                let aDate = (a.data()["createdAt"] as? Timestamp)?.dateValue()
                let bDate = (b.data()["createdAt"] as? Timestamp)?.dateValue()
                if let aDate, let bDate { return aDate < bDate }

                let aName = (a.data()["fullName"] as? String) ?? ""
                let bName = (b.data()["fullName"] as? String) ?? ""
                return aName.localizedCaseInsensitiveCompare(bName) == .orderedAscending
            }

            DispatchQueue.main.async {
                guard self.renderToken == myToken else { return }

                for (index, doc) in sorted.enumerated() {
                    let data = doc.data()

                    let techUID = doc.documentID
                    let fullName = (data["fullName"] as? String) ?? "Unknown"
                    let department = (data["Department"] as? String) ?? "—"
                    let isActive = (data["isActive"] as? Bool) ?? true

                    guard let card = templateCard.cloneView() else { continue }

                    card.isHidden = false
                    card.tag = 0

                    self.configureTechCard(
                        card,
                        techUID: techUID,
                        fullName: fullName,
                        department: department,
                        isActive: isActive,
                        number: index + 1
                    )

                    stackView.addArrangedSubview(card)
                }
            }
        }
    }

    // MARK: - Find stackView without an outlet
    private func findTechStackView() -> UIStackView? {
        return view.findSubview(ofType: UIStackView.self) { stack in
            stack.axis == .vertical && stack.arrangedSubviews.contains(where: { $0.tag == 1 })
        }
    }

    // MARK: - Card UI
    private func configureTechCard(_ card: UIView,
                                   techUID: String,
                                   fullName: String,
                                   department: String,
                                   isActive: Bool,
                                   number: Int) {

        let (firstNameLabel, secondNameLabel, deptLabel) = findFirstSecondDeptLabels(in: card)
        let badgeButton = findBadgeButton(in: card)

        // We will reuse the same storyboard button (it was "Delete") and switch its title to Activate when needed
        let actionButton = findDeleteOrActivateButton(in: card)

        // ✅ NEW: Edit button
        let editButton = findEditButton(in: card)

        // Name split
        let parts = fullName.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if parts.isEmpty {
            firstNameLabel?.text = "Unknown"
            secondNameLabel?.text = ""
        } else if parts.count == 1 {
            firstNameLabel?.text = parts[0]
            secondNameLabel?.text = ""
        } else {
            firstNameLabel?.text = parts[0]
            secondNameLabel?.text = parts.dropFirst().joined(separator: " ")
        }

        deptLabel?.text = department

        // Badge
        let badge = String(format: "#%03d", number)
        badgeButton?.setTitle(badge, for: .normal)
        badgeButton?.configuration?.title = badge

        // Action button: Delete (deactivate) vs Activate
        if let actionButton {
            let title = isActive ? "Delete" : "Activate"
            actionButton.configuration?.title = title
            actionButton.setTitle(title, for: .normal)

            // Store uid + state on the button
            actionButton.accessibilityIdentifier = techUID
            actionButton.tag = isActive ? 1 : 0  // 1=active -> delete, 0=inactive -> activate

            actionButton.removeTarget(self, action: #selector(handleActionTapped(_:)), for: .touchUpInside)
            actionButton.addTarget(self, action: #selector(handleActionTapped(_:)), for: .touchUpInside)
        }

        // ✅ NEW: Wire Edit -> open edit screen + pass UID
        if let editButton {
            editButton.accessibilityIdentifier = techUID
            editButton.removeTarget(self, action: #selector(handleEditTapped(_:)), for: .touchUpInside)
            editButton.addTarget(self, action: #selector(handleEditTapped(_:)), for: .touchUpInside)
        }
    }

    // MARK: - Delete/Activate logic
    @objc private func handleActionTapped(_ sender: UIButton) {
        guard let uid = sender.accessibilityIdentifier, !uid.isEmpty else { return }

        let isCurrentlyActive = (sender.tag == 1)

        if isCurrentlyActive {
            // Delete => isActive = false
            showProceedCancelAlert(
                title: "Deactivate Technician?",
                message: "This technician will be deactivated.",
                proceedTitle: "Proceed"
            ) { [weak self] in
                self?.setTechnicianActive(uid: uid, active: false)
            }
        } else {
            // Activate => isActive = true
            showProceedCancelAlert(
                title: "Activate Technician?",
                message: "This technician will be activated.",
                proceedTitle: "Proceed"
            ) { [weak self] in
                self?.setTechnicianActive(uid: uid, active: true)
            }
        }
    }

    private func setTechnicianActive(uid: String, active: Bool) {
        db.collection("technicians").document(uid).updateData([
            "isActive": active
        ]) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                self.showSimpleAlert(title: "Error", message: error.localizedDescription)
                return
            }

            // ✅ auto refresh
            self.loadTechniciansAndRender()
        }
    }

    private func showProceedCancelAlert(title: String,
                                       message: String,
                                       proceedTitle: String,
                                       onProceed: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: proceedTitle, style: .destructive) { _ in
            onProceed()
        })
        present(alert, animated: true)
    }

    private func showSimpleAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(a, animated: true)
        }
    }

    // ✅ NEW: Open edit screen + pass UID
    @objc private func handleEditTapped(_ sender: UIButton) {
        guard let uid = sender.accessibilityIdentifier, !uid.isEmpty else { return }

        // Use the current storyboard when possible (safer than hardcoding "Main").
        let sb = self.storyboard ?? UIStoryboard(name: "Main", bundle: nil)
        guard let editVC = sb.instantiateViewController(withIdentifier: "TechListViewController")
                as? TechListViewController else {
            print("❌ Could not instantiate AdminEditTechnicianViewController. Check Storyboard ID + Custom Class.")
            return
        }

        //editVC.technicianUID = uid

        // If this screen isn't embedded in a UINavigationController, push will do nothing.
        // Present modally as a fallback.
        if let nav = self.navigationController {
            nav.pushViewController(editVC, animated: true)
        } else {
            editVC.modalPresentationStyle = .fullScreen
            self.present(editVC, animated: true)
        }
    }

    // MARK: - Find labels/buttons

    private func findFirstSecondDeptLabels(in card: UIView) -> (UILabel?, UILabel?, UILabel?) {
        let labels = card.allSubviews.compactMap { $0 as? UILabel }

        // Two name labels are ~21pt
        let nameLabels = labels.filter { abs($0.font.pointSize - 21) < 0.5 }
        let sortedByY = nameLabels.sorted { $0.frame.minY < $1.frame.minY }
        let firstNameLabel = sortedByY.first
        let secondNameLabel = sortedByY.dropFirst().first

        // Dept label is ~14pt
        let deptLabel = labels.first(where: { abs($0.font.pointSize - 14) < 0.5 })

        return (firstNameLabel, secondNameLabel, deptLabel)
    }

    private func findBadgeButton(in card: UIView) -> UIButton? {
        let buttons = card.allSubviews.compactMap { $0 as? UIButton }
        return buttons.first(where: { button in
            let configTitle = button.configuration?.title ?? ""
            if configTitle.hasPrefix("#") { return true }

            let current = button.currentTitle ?? ""
            if current.hasPrefix("#") { return true }

            let normal = button.title(for: .normal) ?? ""
            return normal.hasPrefix("#")
        })
    }

    // Finds the action button (starts as "Delete" in storyboard; we may change it to "Activate")
    private func findDeleteOrActivateButton(in card: UIView) -> UIButton? {
        let buttons = card.allSubviews.compactMap { $0 as? UIButton }
        return buttons.first(where: { button in
            let t1 = (button.configuration?.title ?? "").lowercased()
            let t2 = (button.currentTitle ?? "").lowercased()
            let t3 = (button.title(for: .normal) ?? "").lowercased()
            return t1 == "delete" || t2 == "delete" || t3 == "delete" ||
                   t1 == "activate" || t2 == "activate" || t3 == "activate"
        })
    }

    // ✅ NEW: Find Edit button
    private func findEditButton(in card: UIView) -> UIButton? {
        let buttons = card.allSubviews.compactMap { $0 as? UIButton }
        return buttons.first(where: { button in
            let t1 = (button.configuration?.title ?? "").lowercased()
            let t2 = (button.currentTitle ?? "").lowercased()
            let t3 = (button.title(for: .normal) ?? "").lowercased()
            return t1 == "edit" || t2 == "edit" || t3 == "edit"
        })
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
