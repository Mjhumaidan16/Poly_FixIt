import UIKit
import SwiftUI
import FirebaseFirestore

// MARK: - Data Model
struct NotificationMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let timestamp: String
}

// MARK: - SwiftUI View
struct StackedNotificationView: View {
    let notifications: [NotificationMessage]
    private let scaleFactor: CGFloat = 1.1

    var body: some View {
        VStack(spacing: 0) {
            if notifications.isEmpty {
                Text("No new notifications")
                    .font(.system(size: 14 * scaleFactor))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(notifications) { item in
                        notificationRow(item)
                        if item.id != notifications.last?.id {
                            Divider().padding(.leading, 50 * scaleFactor)
                        }
                    }
                }
                .padding(.vertical, 8 * scaleFactor)
            }

            Divider()

            Button(action: { print("View All Tapped") }) {
                Text("View All")
                    .font(.system(size: 16 * scaleFactor, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14 * scaleFactor)
            }
        }
        .frame(width: 220)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .scaleEffect(scaleFactor)
    }

    private func notificationRow(_ item: NotificationMessage) -> some View {
        HStack(alignment: .top, spacing: 10 * scaleFactor) {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 32 * scaleFactor, height: 32 * scaleFactor)
                .overlay(Image(systemName: "bell.fill").font(.system(size: 10 * scaleFactor)))
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.title).font(.system(size: 14 * scaleFactor, weight: .bold))
                    Spacer()
                    Text(item.timestamp).font(.system(size: 10 * scaleFactor)).foregroundColor(.secondary)
                }
                Text(item.message).font(.system(size: 12 * scaleFactor)).foregroundColor(.secondary).lineLimit(2)
            }
        }
        .padding(12 * scaleFactor)
    }
}

// MARK: - Custom Notification Bar Button Item
class NotificationButton: UIBarButtonItem {
    
    private var messages: [NotificationMessage] = []
    private var hostingController: UIHostingController<StackedNotificationView>?
    private var isPanelVisible = false
    private let triggerButton = UIButton(type: .system)
    private let badgeLabel = UILabel()
    private let db = Firestore.firestore()

    override init() {
        super.init()
        setup()
        fetchNotificationsFromFirebase()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        fetchNotificationsFromFirebase()
    }

    private func setup() {
        triggerButton.setImage(UIImage(systemName: "bell.fill"), for: .normal)
        triggerButton.tintColor = .white
        triggerButton.frame = CGRect(x: 0, y: 0, width: 35, height: 35)
        triggerButton.addTarget(self, action: #selector(togglePanel), for: .touchUpInside)
        
        badgeLabel.backgroundColor = .red
        badgeLabel.textColor = .white
        badgeLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        badgeLabel.isHidden = true
        badgeLabel.frame = CGRect(x: 20, y: 0, width: 16, height: 16)
        
        triggerButton.addSubview(badgeLabel)
        self.customView = triggerButton
    }

    @objc private func togglePanel() {
        guard let parentVC = triggerButton.findParentViewController else { return }
        if isPanelVisible { hidePanel() } else { showPanel(in: parentVC); updateBadge(count: 0) }
        isPanelVisible.toggle()
    }

    private func fetchNotificationsFromFirebase() {
        let userRef = db.collection("users").document("00")
        db.collection("notifications")
            .whereField("receiver", isEqualTo: userRef)
            .order(by: "time", descending: true)
            .limit(to: 3)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let docs = snapshot?.documents else { return }
                self.messages = docs.map { doc in
                    let data = doc.data()
                    let sender = data["triggeredby"] as? String ?? "System"
                    let msg = data["message"] as? String ?? ""
                    var timeStr = "Now"
                    if let ts = data["time"] as? Timestamp {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "h:mm a"
                        timeStr = formatter.string(from: ts.dateValue())
                    }
                    return NotificationMessage(title: sender, message: msg, timestamp: timeStr)
                }
                if docs.count > 0 { self.updateBadge(count: docs.count) }
                if self.isPanelVisible { self.refreshPanel() }
            }
    }

    private func updateBadge(count: Int) {
        DispatchQueue.main.async {
            self.badgeLabel.text = count > 0 ? "\(count)" : ""
            self.badgeLabel.isHidden = count == 0
        }
    }

    private func showPanel(in parent: UIViewController) {
        let swiftView = StackedNotificationView(notifications: self.messages)
        let hc = UIHostingController(rootView: swiftView)
        self.hostingController = hc
        
        hc.view.backgroundColor = UIColor.clear
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        
        parent.addChild(hc)
        parent.view.addSubview(hc.view)
        hc.didMove(toParent: parent)

        NSLayoutConstraint.activate([
            hc.view.topAnchor.constraint(equalTo: triggerButton.bottomAnchor, constant: 10),
            // CHANGED: Increased the constant to -40 to move the panel further left
            hc.view.trailingAnchor.constraint(equalTo: parent.view.trailingAnchor, constant: -40)
        ])

        hc.view.alpha = 0
        hc.view.transform = CGAffineTransform(translationX: 0, y: -10)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            hc.view.alpha = 1
            hc.view.transform = .identity
        }
    }

    private func refreshPanel() {
        let swiftView = StackedNotificationView(notifications: self.messages)
        hostingController?.rootView = swiftView
    }

    private func hidePanel() {
        UIView.animate(withDuration: 0.2, animations: {
            self.hostingController?.view.alpha = 0
        }) { _ in
            self.hostingController?.view.removeFromSuperview()
            self.hostingController?.removeFromParent()
            self.hostingController = nil
        }
    }
}

// MARK: - Helper Extension
extension UIView {
    var findParentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder?.next
            if let viewController = parentResponder as? UIViewController { return viewController }
        }
        return nil
    }
}
