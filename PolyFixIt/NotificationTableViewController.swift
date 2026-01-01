//
//  NotificationTableViewController.swift
//  PolyFixIt
//
//  Created by BP-36-212-02 on 31/12/2025.
//

import UIKit
import FirebaseFirestore

class NotificationTableViewController: UITableViewController {
    
    // مصفوفة لتخزين بيانات الإشعارات
    var notifications: [[String: Any]] = []
    let db = Firestore.firestore()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // إعداد العنوان في واجهة المستخدم
        self.title = "Notifications"
        
        // الاستماع للإشعارات الخاصة بالمستخدم "00"
        listenToNotifications(forUser: "00")
        
        // إعداد الجدول ليدعم الأسطر المتعددة وتغيير الارتفاع تلقائياً
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
    }

    // MARK: - Firebase Logic
    
    func listenToNotifications(forUser userID: String) {
        let userRef = db.collection("users").document(userID)
        
        db.collection("notifications")
            .whereField("receiver", isEqualTo: userRef)
            .order(by: "time", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching notifications: \(error.localizedDescription)")
                    return
                }
                
                guard let docs = snapshot?.documents else { return }
                self?.notifications = docs.map { $0.data() }
                
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            }
    }

    // MARK: - Table View Data Source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifications.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // تأكد أن Identifier هو "cell" في Storyboard
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let data = notifications[indexPath.row]
        
        // 1. استخراج البيانات
        let sender = data["triggeredby"] as? String ?? "System"
        let message = data["message"] as? String ?? "No content"
        
        // 2. تنسيق الوقت والتاريخ
        var fullDateString = ""
        if let timestamp = data["time"] as? Timestamp {
            let date = timestamp.dateValue()
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            formatter.locale = Locale(identifier: "en_US")
            fullDateString = formatter.string(from: date)
        }
        
        // 3. ترتيب المعلومات في أسطر منفصلة (From, Message, Date)
        cell.textLabel?.numberOfLines = 0 // يسمح بتعدد الأسطر
        cell.textLabel?.text = "From: \(sender)\nMessage: \(message)\nDate: \(fullDateString)"
        
        // 4. تغيير لون الخط فقط إلى الأبيض
        cell.textLabel?.textColor = .white
        
        // إذا كان هناك عنوان فرعي مستخدم (Detail Label)
        cell.detailTextLabel?.textColor = .white
        
        return cell
    }
}
