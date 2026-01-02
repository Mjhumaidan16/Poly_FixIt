//
//  RequestFilterViewController.swift
//  PolyFixIt
//
//  Created by BP-36-212-08 on 31/12/2025.
//

import UIKit

final class RequestFilterViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet private weak var datePicker: UIDatePicker!
    @IBOutlet private weak var categoryButton: UIButton!
    @IBOutlet private weak var statusButton: UIButton!
    @IBOutlet private weak var confirmButton: UIButton!

    // MARK: - Current selections (what we pass to UserRequestList)
    private var selectedCategory: String?
    private var selectedStatus: String?
    private var selectedDate: Date?

    // These are the real categories your app saves to Firestore (from AddRequsetViewController)
    private let validCategories: [String] = ["Plumbing", "IT", "HVAC", "Furniture", "Safety"]

    // Status titles should match your filter menu titles
    private let validStatusTitles: [String] = ["Not Assigned", "In Progress", "Done"]

    override func viewDidLoad() {
        super.viewDidLoad()

        selectedDate = datePicker.date

        //  Only treat the current button title as a selection if it's actually valid
        selectedCategory = canonicalCategory(from: readButtonTitle(categoryButton))
        selectedStatus = canonicalStatus(from: readButtonTitle(statusButton))

        datePicker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)

        rebuildMenusFromStoryboard()
    }

    @objc private func dateChanged(_ sender: UIDatePicker) {
        selectedDate = sender.date
    }

    // MARK: - Segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let listVC = segue.destination as? UserRequestListViewController {
            listVC.filterCategory = selectedCategory
            listVC.filterStatus = selectedStatus
            listVC.filterDate = selectedDate

            // Debug (optional)
            print("➡️ Passing filterCategory:", selectedCategory ?? "nil")
        }
    }

    // MARK: - Menus
    private func rebuildMenusFromStoryboard() {

        // CATEGORY MENU
        if let existing = categoryButton.menu {
            let titles = existing.children
                .compactMap { ($0 as? UICommand)?.title }
                .filter { !$0.isEmpty }

            if !titles.isEmpty {
                categoryButton.menu = UIMenu(
                    title: existing.title,
                    options: [.singleSelection],
                    children: titles.map { title in

                        let canonical = canonicalCategory(from: title)
                        let isSelected = (canonical != nil && canonical == selectedCategory)

                        return UIAction(
                            title: title,
                            state: isSelected ? .on : .off
                        ) { [weak self] action in
                            guard let self = self else { return }

                            //  SAFETY FIX:
                            // If storyboard typo exists (e.g., "Saftey"), correct it to "Safety"
                            let raw = action.title.trimmingCharacters(in: .whitespacesAndNewlines)
                            let corrected = (normalize(raw) == "saftey") ? "Safety" : raw

                            //  store canonical Firestore value if possible
                            self.selectedCategory = self.canonicalCategory(from: corrected) ?? corrected

                            self.setButtonTitle(self.categoryButton, title: corrected)
                            self.rebuildMenusFromStoryboard()
                        }
                    }
                )
                categoryButton.showsMenuAsPrimaryAction = true
            }
        }

        // STATUS MENU
        if let existing = statusButton.menu {
            let titles = existing.children
                .compactMap { ($0 as? UICommand)?.title }
                .filter { !$0.isEmpty }

            if !titles.isEmpty {
                statusButton.menu = UIMenu(
                    title: existing.title,
                    options: [.singleSelection],
                    children: titles.map { title in

                        let canonical = canonicalStatus(from: title)
                        let isSelected = (canonical != nil && canonical == selectedStatus)

                        return UIAction(
                            title: title,
                            state: isSelected ? .on : .off
                        ) { [weak self] action in
                            guard let self = self else { return }

                            self.selectedStatus = self.canonicalStatus(from: action.title)

                            self.setButtonTitle(self.statusButton, title: action.title)
                            self.rebuildMenusFromStoryboard()
                        }
                    }
                )
                statusButton.showsMenuAsPrimaryAction = true
            }
        }
    }

    // MARK: - Title helpers (supports iOS 15 UIButton.Configuration)
    private func readButtonTitle(_ button: UIButton) -> String? {
        if #available(iOS 15.0, *), let cfg = button.configuration {
            if let t = cfg.attributedTitle?.characters {
                let s = String(t).trimmingCharacters(in: .whitespacesAndNewlines)
                return s.isEmpty ? nil : s
            }
            let s = (cfg.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : s
        }

        let s = (button.currentTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }

    private func setButtonTitle(_ button: UIButton, title: String) {
        if #available(iOS 15.0, *), var cfg = button.configuration {
            cfg.title = title
            cfg.attributedTitle = nil
            button.configuration = cfg
        } else {
            button.setTitle(title, for: .normal)
        }
    }

    // MARK: - Canonicalizers

    private func normalize(_ s: String?) -> String {
        return (s ?? "")
            .replacingOccurrences(of: "\u{00A0}", with: " ") // NBSP
            .replacingOccurrences(of: "\u{200B}", with: "")  // zero-width space
            .replacingOccurrences(of: "\u{200C}", with: "")  // ZWNJ
            .replacingOccurrences(of: "\u{200D}", with: "")  // ZWJ
            .replacingOccurrences(of: "\u{FEFF}", with: "")  // BOM
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// Returns canonical Firestore category (e.g., "Safety") or nil if placeholder/invalid.
    private func canonicalCategory(from title: String?) -> String? {
        let key = normalize(title)
        guard !key.isEmpty else { return nil }

        for c in validCategories {
            if normalize(c) == key { return c }
        }
        return nil
    }

    /// Returns canonical status title or nil if placeholder/invalid.
    private func canonicalStatus(from title: String?) -> String? {
        let key = normalize(title)
        guard !key.isEmpty else { return nil }

        for s in validStatusTitles {
            if normalize(s) == key { return s }
        }
        return nil
    }
}
