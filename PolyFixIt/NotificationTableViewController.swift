//
//  Untitled.swift
//  PolyFixIt
//
//  Created by BP-36-212-02 on 31/12/2025.
//

import UIKit
import FirebaseFirestore

class NotificationTableViewController: UITableViewController {
    
    var notifications: [[String: Any]] = []
    let db = Firestore.firestore()

    override func viewDidLoad() {
        super.viewDidLoad()
        // استبدل "00" بالـ ID الخاص بك مؤقتاً للتجربة
        listenToNotifications(forUser: "00")
    }

    func listenToNotifications(forUser userID: String) {
        let userRef = db.collection("users").document(userID)
        
        db.collection("notifications")
            .whereField("receiver", isEqualTo: userRef)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                self.notifications = docs.map { $0.data() }
                self.tableView.reloadData()
            }
    }

    // -- إعدادات الجدول التلقائية --
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifications.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let data = notifications[indexPath.row]
        
        // عرض الرسالة والحالة بأبسط شكل
        cell.textLabel?.text = data["message"] as? String
        cell.detailTextLabel?.text = data["status"] as? String
        return cell
    }
}
