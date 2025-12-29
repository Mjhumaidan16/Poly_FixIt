import UIKit
import FirebaseFirestore

final class UserRequestListViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet private weak var requestsStackView: UIStackView!
    @IBOutlet private weak var scrollView: UIScrollView? // connect if you have one; ok if nil

    // MARK: - Firestore
    private let db = Firestore.firestore()

    // You said the ref looks like: /users/bmVxg...
    private let submittedByPathWithSlash = "/users/bmVxgwiDv3MIFMLWgfb7hxOrHsl2"

    // Template card (tag = 1)
    private var templateCard: UIView?

    // listeners
    private var l1: ListenerRegistration?
    private var l2: ListenerRegistration?
    private var l3: ListenerRegistration?

    // latest docs from each listener
    private var docsA: [QueryDocumentSnapshot] = []
    private var docsB: [QueryDocumentSnapshot] = []
    private var docsC: [QueryDocumentSnapshot] = []

    // cards
    private var generatedCards: [UIView] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTemplate()
        removeStackHeightConstraintsIfAny()
        listenAllWays()
    }

    deinit {
        l1?.remove(); l2?.remove(); l3?.remove()
    }

    // MARK: - Template
    private func setupTemplate() {
        templateCard = requestsStackView.arrangedSubviews.first(where: { $0.tag == 1 })
        templateCard?.isHidden = true

        if templateCard == nil {
            print("❌ Template card not found. Ensure ONE card inside stackView has tag=1.")
        }
    }

    // MARK: - Critical UI fix: remove fixed height constraints that clip the list
    private func removeStackHeightConstraintsIfAny() {
        // Any height constraint directly on stack view can cause “only 1 card visible”
        let bad = requestsStackView.constraints.filter { c in
            c.firstAttribute == .height && c.relation == .equal
        }
        if !bad.isEmpty {
            bad.forEach { $0.isActive = false }
            print("✅ Disabled stackView height constraints:", bad.count)
        }

        // Also check superview constraints that pin stack height
        if let superV = requestsStackView.superview {
            let bad2 = superV.constraints.filter { c in
                (c.firstItem as? UIView) == requestsStackView &&
                c.firstAttribute == .height &&
                c.relation == .equal
            }
            if !bad2.isEmpty {
                bad2.forEach { $0.isActive = false }
                print("✅ Disabled superview->stack height constraints:", bad2.count)
            }
        }
    }

    // MARK: - Firestore: listen 3 ways (Reference + leading slash + String) then merge
    private func listenAllWays() {
        l1?.remove(); l2?.remove(); l3?.remove()

        let ref = db.document(submittedByPathWithSlash)

        // A) submittedBy stored as DocumentReference "users/.."
        l1 = db.collection("requests")
            .whereField("submittedBy", isEqualTo: ref)
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err { print("❌ listen A error:", err.localizedDescription); return }
                self.docsA = snap?.documents ?? []
                self.mergeSortRender()
            }


        // C) submittedBy stored as String "/users/.."
        l3 = db.collection("requests")
            .whereField("submittedBy", isEqualTo: submittedByPathWithSlash)
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err { print("❌ listen C error:", err.localizedDescription); return }
                self.docsC = snap?.documents ?? []
                self.mergeSortRender()
            }
    }

    private func mergeSortRender() {
        // merge + dedupe
        var map: [String: QueryDocumentSnapshot] = [:]
        for d in docsA { map[d.documentID] = d }
        for d in docsB { map[d.documentID] = d }
        for d in docsC { map[d.documentID] = d }

        var merged = Array(map.values)

        // local sort by createdAt desc (missing dates go last)
        merged.sort { a, b in
            let da = (a.data()["createdAt"] as? Timestamp)?.dateValue()
            let db = (b.data()["createdAt"] as? Timestamp)?.dateValue()
            switch (da, db) {
            case let (.some(x), .some(y)): return x > y
            case (.some, .none): return true
            case (.none, .some): return false
            default: return a.documentID > b.documentID
            }
        }

        print("✅ Total merged docs:", merged.count, "IDs:", merged.map { $0.documentID })

        DispatchQueue.main.async { [weak self] in
            self?.renderRequests(merged)
        }
    }

    // MARK: - Render
    private func renderRequests(_ docs: [QueryDocumentSnapshot]) {
        // clear old
        for card in generatedCards {
            requestsStackView.removeArrangedSubview(card)
            card.removeFromSuperview()
        }
        generatedCards.removeAll()

        guard let template = templateCard else { return }

        // compute a reasonable height (helps stack layout)
        let templateH = template.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        let safeH = max(templateH, 120)

        for (idx, doc) in docs.enumerated() {
            let data = doc.data()

            guard let card: UIView = template.deepCopyView() else { continue }
            card.isHidden = false
            card.translatesAutoresizingMaskIntoConstraints = false

            // give each card a predictable height so stack grows
            let h = card.heightAnchor.constraint(equalToConstant: safeH)
            h.priority = .defaultHigh
            h.isActive = true

            card.accessibilityIdentifier = "requestCard_\(idx)"

            let title = (data["title"] as? String) ?? ""
            let category = (data["category"] as? String)
                        ?? (data["selectedCategory"] as? String)
                        ?? ""

            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
            let imageUrl = (data["imageUrl"] as? String) ?? ""

            let assignedRef =
                (data["assignedTech"] as? DocumentReference)
                ?? (data["assignedTechnician"] as? DocumentReference)

            let status = ((data["status"] as? String) ?? (data["Status"] as? String) ?? "").lowercased()

            applyCardContent(card,
                             title: title,
                             category: category,
                             createdAt: createdAt,
                             assignedRef: assignedRef,
                             status: status,
                             imageUrl: imageUrl)

            requestsStackView.addArrangedSubview(card)
            generatedCards.append(card)
        }

        // force layout
        view.setNeedsLayout()
        view.layoutIfNeeded()
        (scrollView ?? requestsStackView.findAncestorScrollView())?.setNeedsLayout()
        (scrollView ?? requestsStackView.findAncestorScrollView())?.layoutIfNeeded()
    }

    // MARK: - Bind
    private func applyCardContent(
        _ card: UIView,
        title: String,
        category: String,
        createdAt: Date?,
        assignedRef: DocumentReference?,
        status: String,
        imageUrl: String
    ) {
        let imageView = card.findFirst(UIImageView.self)

        let labels = card.findAll(UILabel.self)
        let titleLabel = labels.first(where: { abs($0.font.pointSize - 21) < 0.6 })
        let categoryLabel = labels.first(where: { abs($0.font.pointSize - 14) < 0.6 })
        let submittedLabel =
            labels.first(where: { ($0.text ?? "").lowercased().contains("submitted") }) ??
            labels.first(where: { abs($0.font.pointSize - 13) < 0.6 })

        let buttons = card.findAll(UIButton.self)
        let statusButton =
            buttons.first(where: { ($0.currentTitle ?? "").localizedCaseInsensitiveContains("not assigned") }) ??
            buttons.first(where: { ($0.titleLabel?.font.pointSize ?? 999) < 12 })

        titleLabel?.text = title
        categoryLabel?.text = category

        if let createdAt = createdAt {
            let df = DateFormatter()
            df.dateFormat = "dd-MM-yyyy"
            submittedLabel?.text = "Submitted: \(df.string(from: createdAt))"
        } else {
            submittedLabel?.text = "Submitted: -"
        }

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

        if let statusButton = statusButton {
            let font = UIFont.systemFont(ofSize: 9, weight: .bold)
            let color = statusButton.titleColor(for: .normal) ?? .white
            statusButton.setAttributedTitle(NSAttributedString(string: statusText, attributes: [
                .font: font,
                .foregroundColor: color
            ]), for: .normal)

            statusButton.titleLabel?.numberOfLines = 1
            statusButton.titleLabel?.adjustsFontSizeToFitWidth = true
            statusButton.titleLabel?.minimumScaleFactor = 0.5
            statusButton.titleLabel?.lineBreakMode = .byTruncatingTail
        }

        // ✅ Better image handling (fixes “one card loads image, other doesn’t”)
        let clean = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        if let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           !encoded.isEmpty,
           let url = URL(string: encoded) {

            // optional placeholder / reset to avoid reuse artifacts
            imageView?.image = nil

            ImageLoader.shared.load(url: url) { [weak imageView] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let img):
                        imageView?.image = img
                    case .failure(let err):
                        print("❌ Image load failed:", url.absoluteString, "error:", err.localizedDescription)
                        imageView?.image = nil
                    }
                }
            }
        } else {
            print("⚠️ Bad imageUrl:", imageUrl)
            imageView?.image = nil
        }
    }
}

// MARK: - Image loader with cache
final class ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private init() {}

    func load(url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) {
        let key = url as NSURL

        if let cached = cache.object(forKey: key) {
            completion(.success(cached))
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data, let img = UIImage(data: data) else {
                completion(.failure(NSError(
                    domain: "ImageLoader",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Bad image data"]
                )))
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
        for sub in subviews {
            if let found: T = sub.findFirst(type) { return found }
        }
        return nil
    }

    func findAll<T: UIView>(_ type: T.Type) -> [T] {
        var result: [T] = []
        if let v = self as? T { result.append(v) }
        for sub in subviews {
            result.append(contentsOf: sub.findAll(type))
        }
        return result
    }

    func deepCopyView<T: UIView>() -> T? {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
            return try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? T
        } catch {
            print("❌ deepCopyView failed:", error)
            return nil
        }
    }

    func findAncestorScrollView() -> UIScrollView? {
        var v: UIView? = self
        while let cur = v {
            if let sv = cur as? UIScrollView { return sv }
            v = cur.superview
        }
        return nil
    }
}
