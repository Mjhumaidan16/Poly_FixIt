import UIKit
import SwiftUI
import FirebaseFirestore

// MARK: - 1) Buildings (3 pins)
enum CampusBuilding: String, CaseIterable {
    case building5  = "Building 5, 67, 15"
    case building19 = "Building 19, 66, 36"
    case building36 = "Building 36, 31, 12"

    var data: (name: String, x: CGFloat, y: CGFloat) {
        let components = self.rawValue.components(separatedBy: ", ")
        let name = components[0]
        let xValue = CGFloat(Double(components[safe: 1] ?? "0") ?? 0) / 100.0
        let yValue = CGFloat(Double(components[safe: 2] ?? "0") ?? 0) / 100.0
        return (name, xValue, yValue)
    }

    /// The building number we expect from Firestore `location.building[0]` e.g. "5", "19", "36"
    var buildingNumberString: String {
        switch self {
        case .building5:  return "5"
        case .building19: return "19"
        case .building36: return "36"
        }
    }

    init?(buildingNumberFromFirestore: String) {
        let trimmed = buildingNumberFromFirestore.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed {
        case "5":  self = .building5
        case "19": self = .building19
        case "36": self = .building36
        default: return nil
        }
    }
}

// MARK: - 2) Overlay marker model
struct FacilityIssue: Identifiable {
    let id = UUID()
    let building: CampusBuilding
    let color: Color
}

// MARK: - 3) SwiftUI overlay (pins)
struct PinOverlayView: View {
    var issues: [FacilityIssue]
    var onTap: (FacilityIssue) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.clear

                ForEach(issues) { issue in
                    Button(action: { onTap(issue) }) {
                        VStack(spacing: 2) {
                            Text(issue.building.data.name)
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.85))
                                .cornerRadius(3)

                            Circle()
                                .fill(issue.color)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 70, height: 40)
                    .contentShape(Rectangle())
                    .position(
                        x: issue.building.data.x * geometry.size.width,
                        y: issue.building.data.y * geometry.size.height
                    )
                }
            }
        }
    }
}

// MARK: - 4) Firestore row model (what you want displayed)
private struct RequestRowModel {
    let id: String
    let title: String
    let assignedTech: String
    let priority: String
    let locationText: String
    let buildingNumber: String
    let buildingEnum: CampusBuilding?
}

// MARK: - 5) Your existing storyboard VC (same scene)
final class FacilityMapViewController: UIViewController {

    // Already in your storyboard connections :contentReference[oaicite:1]{index=1}
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!

    // ✅ Connect this to the vertical stack view inside “Stack Host View”
    @IBOutlet weak var requestsStackView: UIStackView!
    @IBOutlet weak var Header: UILabel!
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // All requests cached from Firestore
    private var allRows: [RequestRowModel] = []

    // Current filter
    private var selectedBuilding: CampusBuilding? = nil

    // Pins you want (3 buildings)
    private let activeIssues: [FacilityIssue] = [
        FacilityIssue(building: .building5,  color: .red),
        FacilityIssue(building: .building19, color: .red),
        FacilityIssue(building: .building36, color: .red)
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        startListeningToRequests()
    }

    deinit {
        listener?.remove()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupOverlay() // keep overlay aligned with image size
    }

    // MARK: - Overlay setup
    private func setupOverlay() {
        // Remove old overlay
        scrollView.subviews
            .filter { $0.accessibilityLabel == "Overlay" }
            .forEach { $0.removeFromSuperview() }

        let overlay = PinOverlayView(issues: activeIssues) { [weak self] issue in
            self?.handlePinTap(issue)
        }

        let hostingController = UIHostingController(rootView: overlay)
        hostingController.view.backgroundColor = .clear
        hostingController.view.accessibilityLabel = "Overlay"
        hostingController.view.isUserInteractionEnabled = true

        addChild(hostingController)
        scrollView.addSubview(hostingController.view)

        // Overlay must match the imageView’s frame inside the scrollView content
        hostingController.view.frame = imageView.frame

        hostingController.didMove(toParent: self)
    }

    private func handlePinTap(_ issue: FacilityIssue) {
        // Filter stack view by building tapped
        selectedBuilding = issue.building
        renderFilteredRows()
    }

    // MARK: - Firestore listener
    private func startListeningToRequests() {
        listener?.remove()

        listener = db.collection("requests")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ requests listener error:", error)
                    return
                }

                let docs = snapshot?.documents ?? []
                self.allRows = docs.map { self.parseRequestRow(from: $0) }

                DispatchQueue.main.async {
                    self.renderFilteredRows()
                }
            }
    }

    // MARK: - Parsing
    private func parseRequestRow(from doc: QueryDocumentSnapshot) -> RequestRowModel {
        let data = doc.data()

        let title = (data["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTitle = (title?.isEmpty == false) ? title! : "(No Title)"

        let priority = (data["selectedPriorityLevel"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let safePriority = (priority?.isEmpty == false) ? priority! : "unknown"

        // assignedTechnician: DocumentReference? OR null
        let techRef = data["assignedTechnician"] as? DocumentReference
        let assignedTechId = techRef?.documentID ?? "Unassigned"

        // location map: campus/building/room are arrays with 1 string
        let locationMap = data["location"] as? [String: Any]
        let campus = (locationMap?["campus"] as? [String])?.first ?? "-"
        let building = (locationMap?["building"] as? [String])?.first ?? "-"
        let room = (locationMap?["room"] as? [String])?.first ?? "-"

        let locationText = "\(campus) • B\(building) • R\(room)"
        let buildingEnum = CampusBuilding(buildingNumberFromFirestore: building)

        return RequestRowModel(
            id: doc.documentID,
            title: safeTitle,
            assignedTech: assignedTechId,
            priority: safePriority,
            locationText: locationText,
            buildingNumber: building,
            buildingEnum: buildingEnum
        )
    }

    // MARK: - Render (filter + stack view)
    private func renderFilteredRows() {
        let rowsToShow: [RequestRowModel]
        if let selectedBuilding = selectedBuilding {
            rowsToShow = allRows.filter { $0.buildingNumber == selectedBuilding.buildingNumberString }
        } else {
            rowsToShow = allRows
        }

        // Clear old UI
        requestsStackView.arrangedSubviews.forEach { v in
            requestsStackView.removeArrangedSubview(v)
            v.removeFromSuperview()
        }

        // Header label (shows current filter)
        Header.textColor = .white
        Header.numberOfLines = 2
        Header.font = .systemFont(ofSize: 16, weight: .semibold)
        if let b = selectedBuilding {
            Header.text = "\(b.data.name) (\(rowsToShow.count))"
        } else {
            Header.text = "All Requests (\(rowsToShow.count))"
        }
//        requestsStackView.addArrangedSubview(header)

        if rowsToShow.isEmpty {
            let empty = UILabel()
            empty.text = "No requests for this building"
            empty.textAlignment = .center
            empty.numberOfLines = 0
            empty.textColor = UIColor(white: 1.0, alpha: 0.8)
            empty.font = .systemFont(ofSize: 14, weight: .regular)
            requestsStackView.addArrangedSubview(empty)
            return
        }

        for row in rowsToShow {
            requestsStackView.addArrangedSubview(makeCardView(for: row))
        }
    }

    private func makeCardView(for row: RequestRowModel) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(white: 1.0, alpha: 0.10)
        container.layer.cornerRadius = 14
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor(white: 1.0, alpha: 0.15).cgColor

        let titleLabel = UILabel()
        titleLabel.text = row.title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2

        let locationLabel = UILabel()
        locationLabel.text = "📍 \(row.locationText)"
        locationLabel.font = .systemFont(ofSize: 14, weight: .regular)
        locationLabel.textColor = UIColor(white: 1.0, alpha: 0.85)
        locationLabel.numberOfLines = 2

        let techLabel = UILabel()
        techLabel.text = "👷 \(row.assignedTech)"
        techLabel.font = .systemFont(ofSize: 14, weight: .regular)
        techLabel.textColor = UIColor(white: 1.0, alpha: 0.85)
        techLabel.numberOfLines = 1

        let priorityLabel = UILabel()
        priorityLabel.text = "⚡ Priority: \(row.priority)"
        priorityLabel.font = .systemFont(ofSize: 14, weight: .regular)
        priorityLabel.textColor = UIColor(white: 1.0, alpha: 0.85)
        priorityLabel.numberOfLines = 1

        let vStack = UIStackView(arrangedSubviews: [titleLabel, locationLabel, techLabel, priorityLabel])
        vStack.axis = .vertical
        vStack.spacing = 6
        vStack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(vStack)

        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            vStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            vStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            vStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            container.heightAnchor.constraint(equalToConstant: 120)
        ])
        
        return container
    }
}

// MARK: - Safe indexing helper
private extension Array where Element == String {
    subscript(safe index: Int) -> String? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
