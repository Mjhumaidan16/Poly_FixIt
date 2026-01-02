import UIKit
import SwiftUI
import FirebaseFirestore
import UserNotifications

// MARK: - نموذج البيانات
struct NotificationMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let timestamp: String
}

// MARK: - واجهة القائمة المنسدلة (SwiftUI)
struct StackedNotificationView: View {
    let notifications: [NotificationMessage]
    private let scaleFactor: CGFloat = 1.1

    var body: some View {
        VStack(spacing: 0) {
            if notifications.isEmpty {
                Text("لا توجد إشعارات حالياً")
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
            Button(action: { print("show all") }) {
                Text("View All")
                    .font(.system(size: 16 * scaleFactor, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14 * scaleFactor)
            }
        }
        .frame(width: 230)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .scaleEffect(scaleFactor)
    }

    private func notificationRow(_ item: NotificationMessage) -> some View {
        HStack(alignment: .top, spacing: 10 * scaleFactor) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 32 * scaleFactor, height: 32 * scaleFactor)
                .overlay(Image(systemName: "person.fill").font(.system(size: 10 * scaleFactor)).foregroundColor(.blue))
            
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

// MARK: - منطق زر الإشعارات (User)
class NotificationButton: UIBarButtonItem {
    
    private var messages: [NotificationMessage] = []
    private var hostingController: UIHostingController<StackedNotificationView>?
    private var isPanelVisible = false
    private let triggerButton = UIButton(type: .system)
    private let badgeLabel = UILabel()
    private let db = Firestore.firestore()

    override init() {
        super.init()
        setupUI()
        fetchAllUserNotifications()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        fetchAllUserNotifications()
    }

    private func setupUI() {
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
        guard let customView = self.customView, let parentVC = customView.findParentViewController else { return }
        
        if isPanelVisible {
            hidePanel()
        } else {
            showPanel(in: parentVC)
            updateBadge(count: 0) // اختياري: تصفير الشارة عند الفتح
        }
        isPanelVisible.toggle()
    }

    private func fetchAllUserNotifications() {
        db.collection("notifications")
            .order(by: "time", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self, let documents = querySnapshot?.documents else { return }
                
                let userDocs = documents.filter { doc in
                    if let receiverRef = doc.data()["receiver"] as? DocumentReference {
                        return receiverRef.path.contains("users")
                    }
                    return false
                }
                
                self.messages = userDocs.map { doc in
                    let data = doc.data()
                    let sender = data["triggeredby"] as? String ?? "Admin"
                    let msg = data["message"] as? String ?? ""
                    
                    var timeStr = "الآن"
                    if let ts = data["time"] as? Timestamp {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "h:mm a"
                        timeStr = formatter.string(from: ts.dateValue())
                    }
                    
                    return NotificationMessage(title: sender, message: msg, timestamp: timeStr)
                }
                
                self.updateBadge(count: self.messages.count)
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
        let hc = UIHostingController(rootView: StackedNotificationView(notifications: self.messages))
        self.hostingController = hc
        hc.view.backgroundColor = .clear
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        
        parent.addChild(hc)
        parent.view.addSubview(hc.view)
        hc.didMove(toParent: parent)

        // MARK: - تعديل القيود للإزاحة (Constraints)
        NSLayoutConstraint.activate([
            // constant: 60 يدفع المربع للأسفل أكثر بعيداً عن زر الجرس
            hc.view.topAnchor.constraint(equalTo: parent.view.safeAreaLayoutGuide.topAnchor, constant: 60),
            
            // constant: -60 يدفع المربع لجهة اليسار أكثر
            hc.view.trailingAnchor.constraint(equalTo: parent.view.trailingAnchor, constant: -60)
        ])

        hc.view.alpha = 0
        UIView.animate(withDuration: 0.3) {
            hc.view.alpha = 1
        }
    }

    private func refreshPanel() {
        hostingController?.rootView = StackedNotificationView(notifications: self.messages)
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

// MARK: - Extension لتسهيل الوصول للـ View Controller
extension UIView {
    var findParentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder?.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}
