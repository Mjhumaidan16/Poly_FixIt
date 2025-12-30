import UIKit
import FirebaseFirestore
import ObjectiveC

final class UserRequestListViewController: UIViewController, UISearchBarDelegate {

    // MARK: - Outlets
    @IBOutlet private weak var requestsStackView: UIStackView!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var searchBar: UISearchBar!   // ✅ connect to NgM-Mc-Brh

    // MARK: - Firestore
    private let db = Firestore.firestore()
    private let submittedByPathWithSlash = "/users/bmVxgwiDv3MIFMLWgfb7hxOrHsl2"

    // Template card view (Tag = 1)
    private var templateCard: UIView?

    private var listenerRef: ListenerRegistration?
    private var listenerString: ListenerRegistration?

    private var docsRef: [QueryDocumentSnapshot] = []
    private var docsString: [QueryDocumentSnapshot] = []

    // ✅ master + filtered lists
    private var allMergedDocs: [QueryDocumentSnapshot] = []
    private var filteredDocs: [QueryDocumentSnapshot] = []

    // generated cards
    private var generatedCards: [UIView] = []

    // current query
    private var currentSearchText: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        // search setup
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.returnKeyType = .done

        setupTemplate()
        removeStackHeightConstraints()
        listen()
    }

    deinit {
        listenerRef?.remove()
        listenerString?.remove()
    }

    // MARK: - Template
    private func setupTemplate() {
        templateCard = requestsStackView.arrangedSubviews.first(where: { $0.tag == 1 })
        if let t = templateCard {
            t.isHidden = true
        } else {
            print("❌ Template card not found. Set template card Tag = 1 in storyboard.")
        }
    }

    private func removeStackHeightConstraints() {
        requestsStackView.constraints
            .filter { $0.firstAttribute == .height && $0.relation == .equal }
            .forEach { $0.isActive = false }

        if let sv = requestsStackView.superview {
            sv.constraints
                .filter {
                    ($0.firstItem as? UIView) == requestsStackView &&
                    $0.firstAttribute == .height &&
                    $0.relation == .equal
                }
                .forEach { $0.isActive = false }
        }
    }

    // MARK: - Firestore
    private func listen() {
        listenerRef?.remove()
        listenerString?.remove()

        let userRef = db.document(submittedByPathWithSlash)

        // A) submittedBy is DocumentReference
        listenerRef = db.collection("requests")
            .whereField("submittedBy", isEqualTo: userRef)
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err {
                    print("❌ listen(ref) error:", err.localizedDescription)
                    return
                }
                self.docsRef = snap?.documents ?? []
                self.mergeThenFilterThenRender()
            }

        // B) submittedBy is String "/users/.."
        listenerString = db.collection("requests")
            .whereField("submittedBy", isEqualTo: submittedByPathWithSlash)
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err {
                    print("❌ listen(string) error:", err.localizedDescription)
                    return
                }
                self.docsString = snap?.documents ?? []
                self.mergeThenFilterThenRender()
            }
    }

    private func mergeThenFilterThenRender() {
        var map: [String: QueryDocumentSnapshot] = [:]
        docsRef.forEach { map[$0.documentID] = $0 }
        docsString.forEach { map[$0.documentID] = $0 }

        var merged = Array(map.values)
        merged.sort {
            let a = ($0.data()["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast
            let b = ($1.data()["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast
            return a > b
        }

        allMergedDocs = merged
        applySearchFilterAndRender()
    }

    // MARK: - Search (filter)
    private func applySearchFilterAndRender() {
        let q = currentSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if q.isEmpty {
            filteredDocs = allMergedDocs
        } else {
            filteredDocs = allMergedDocs.filter { doc in
                let data = doc.data()
                let title = ((data["title"] as? String) ?? "").lowercased()
                let selectedCategory = ((data["selectedCategory"] as? String) ?? "").lowercased()

                // filter by title (and category as a bonus)
                return title.contains(q) || selectedCategory.contains(q)
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.render(self?.filteredDocs ?? [])
        }
    }

    // UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        currentSearchText = searchText
        applySearchFilterAndRender()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        currentSearchText = ""
        searchBar.text = ""
        searchBar.resignFirstResponder()
        applySearchFilterAndRender()
    }

    // MARK: - Render
    private func render(_ docs: [QueryDocumentSnapshot]) {
        for v in generatedCards {
            requestsStackView.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        generatedCards.removeAll()

        guard let template = templateCard else { return }

        for (idx, doc) in docs.enumerated() {
            guard let card: UIView = template.deepCopyView() else {
                print("❌ deepCopy failed at index:", idx)
                continue
            }
            card.isHidden = false
            applyCard(card, data: doc.data(), docID: doc.documentID)
            requestsStackView.addArrangedSubview(card)
            generatedCards.append(card)
        }

        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    // MARK: - Apply Card Content
    private func applyCard(_ card: UIView, data: [String: Any], docID: String) {

        let labels = card.findAll(UILabel.self)
        let imageView = card.findFirst(UIImageView.self)

        let titleLabel = labels.first { $0.font.pointSize > 18 }
        let categoryLabel = labels.first { abs($0.font.pointSize - 14) < 1 }

        // Submitted label (Tag = 776)
        let submittedLabel = card.viewWithTag(776) as? UILabel

        // Only these tags:
        // 777 = status button (master theme)
        // 779 = action button (Edit -> Chat / Rate) that should COPY theme from 777
        guard let statusButton = card.viewWithTag(777) as? UIButton else { return }
        guard let actionButton = card.viewWithTag(779) as? UIButton else { return }

        // Capture 777 theme BEFORE we change anything
        let masterTheme = ButtonTheme.capture(from: statusButton)

        // Firestore fields
        let assignedRef =
            (data["assignedTechnician"] as? DocumentReference) ??
            (data["assignedTech"] as? DocumentReference)

        let status = ((data["status"] as? String) ?? "").lowercased()
        let imageUrl = (data["imageUrl"] as? String) ?? ""

        // Title/category
        titleLabel?.text = data["title"] as? String
        categoryLabel?.text = (data["selectedCategory"] as? String) ?? (data["category"] as? String)

        // ✅ Submitted / createdAt
        let createdAtDate = (data["createdAt"] as? Timestamp)?.dateValue()
        submittedLabel?.text = "Submitted \(formatDate(createdAtDate))"

        // Status text logic
        let statusText: String
        if assignedRef == nil {
            statusText = "Not Assigned"
        } else if status == "accepted" || status == "begin" {
            statusText = "In Progress"
        } else if status == "completed" {
            statusText = "Done"
        } else {
            statusText = "In Progress"
        }

        // Status button title/font
        applyFontAndTitleToButton(statusButton, title: statusText, fontSize: 11.0)
        masterTheme.apply(to: statusButton)

        // Action button behavior + theme source = 777
        if assignedRef == nil {
            // Not assigned: keep storyboard title ("Edit"), enforce font
            applyFontAndTitleToButton(actionButton, title: actionButton.currentTitle ?? "Edit", fontSize: 11.0)

        } else if status == "accepted" || status == "begin" {
            // In progress: Chat styled like 777
            actionButton.isHidden = false
            actionButton.isEnabled = true
            applyFontAndTitleToButton(actionButton, title: "Chat", fontSize: 11.0)
            masterTheme.apply(to: actionButton)

        } else if status == "completed" {
            // Done: Rate styled like 777
            actionButton.isHidden = false
            actionButton.isEnabled = true
            applyFontAndTitleToButton(actionButton, title: "Rate", fontSize: 11.0)
            masterTheme.apply(to: actionButton)

        } else {
            // default: show edit
            actionButton.isHidden = false
            actionButton.isEnabled = true
            applyFontAndTitleToButton(actionButton, title: actionButton.currentTitle ?? "Edit", fontSize: 11.0)
        }

        // Image
        let clean = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: encoded) {

            imageView?.image = nil
            ImageLoader.shared.load(url: url) { [weak imageView] result in
                DispatchQueue.main.async {
                    if case .success(let img) = result {
                        imageView?.image = img
                    }
                }
            }
        } else {
            imageView?.image = nil
        }
    }

    // MARK: - Helpers
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "dd-MM-yyyy"
        return df.string(from: date)
    }

    private func applyFontAndTitleToButton(_ button: UIButton, title: String, fontSize: CGFloat) {
        let f = UIFont.systemFont(ofSize: fontSize, weight: .bold)

        if #available(iOS 15.0, *), var config = button.configuration {
            var attrs = AttributeContainer()
            attrs.font = f
            config.attributedTitle = AttributedString(title, attributes: attrs)
            button.configuration = config
        } else {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = f
        }

        button.titleLabel?.adjustsFontForContentSizeCategory = false
    }
}

// MARK: - Theme capture/apply for buttons (777 is the source)
private struct ButtonTheme {
    let background: UIColor?
    let titleColor: UIColor?
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let borderColor: UIColor?

    static func capture(from button: UIButton) -> ButtonTheme {
        let bg: UIColor?
        let tc: UIColor?

        if #available(iOS 15.0, *), let cfg = button.configuration {
            bg = cfg.baseBackgroundColor
            tc = cfg.baseForegroundColor
        } else {
            bg = button.backgroundColor
            tc = button.titleColor(for: .normal)
        }

        return ButtonTheme(
            background: bg,
            titleColor: tc,
            cornerRadius: button.layer.cornerRadius,
            borderWidth: button.layer.borderWidth,
            borderColor: (button.layer.borderColor != nil) ? UIColor(cgColor: button.layer.borderColor!) : nil
        )
    }

    func apply(to button: UIButton) {
        if #available(iOS 15.0, *), var cfg = button.configuration {
            cfg.baseBackgroundColor = background
            cfg.baseForegroundColor = titleColor
            button.configuration = cfg
        } else {
            button.backgroundColor = background
            if let tc = titleColor { button.setTitleColor(tc, for: .normal) }
        }

        button.layer.cornerRadius = cornerRadius
        button.layer.borderWidth = borderWidth
        button.layer.borderColor = borderColor?.cgColor
        button.clipsToBounds = true
    }
}

// MARK: - Image Loader
final class ImageLoader {
    static let shared = ImageLoader()
    private let cache = NSCache<NSURL, UIImage>()

    func load(url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            completion(.success(cached))
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data, let img = UIImage(data: data) else {
                completion(.failure(NSError(domain: "ImageLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bad image data"])))
                return
            }
            self?.cache.setObject(img, forKey: key)
            completion(.success(img))
        }.resume()
    }
}

// MARK: - UIView helpers
private extension UIView {

    func findFirst<T: UIView>(_ type: T.Type) -> T? {
        if let v = self as? T { return v }
        for s in subviews {
            if let found: T = s.findFirst(type) { return found }
        }
        return nil
    }

    func findAll<T: UIView>(_ type: T.Type) -> [T] {
        var result: [T] = []
        if let v = self as? T { result.append(v) }
        for s in subviews { result.append(contentsOf: s.findAll(type)) }
        return result
    }

    func deepCopyView<T: UIView>() -> T? {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            defer { unarchiver.finishDecoding() }
            return unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? T
        } catch {
            print("❌ deepCopyView failed:", error)
            return nil
        }
    }
}
