import Foundation
import FirebaseFirestore

class NotificationReader {
    let db = Firestore.firestore()

    func fetchAllNotifications() {
        // الوصول إلى مجموعة notifications
        db.collection("notifications").addSnapshotListener { (querySnapshot, error) in
            if let error = error {
                print("Error getting notifications: \(error.localizedDescription)")
                return
            }

            // التأكد من وجود مستندات
            guard let documents = querySnapshot?.documents else {
                print("No notifications found")
                return
            }

            // الدخول إلى كل مستند وقراءة الحقول
            for document in documents {
                let data = document.data() // تحويل المستند إلى Dictionary

                // 1. قراءة نص الرسالة (String)
                let message = data["message"] as? String ?? ""

                // 2. قراءة حالة التنبيه (String)
                let status = data["status"] as? String ?? "unread"

                // 3. قراءة من الذي فجر التنبيه (String)
                let triggeredBy = data["triggeredby"] as? String ?? ""

                // 4. قراءة الوقت (Timestamp) وتحويله إلى تاريخ Swift
                let timestamp = data["time"] as? Timestamp
                let date = timestamp?.dateValue() ?? Date()

                // 5. قراءة المرجع (Reference) الخاص بالمستقبل
                // ملاحظة: المرجع هو رابط لمستند آخر وليس مجرد نص
                let receiverRef = data["receiver"] as? DocumentReference
                let receiverID = receiverRef?.documentID ?? "No ID"

                // الآن يمكنك طباعة النتائج أو عرضها في الواجهة
                print("--- Notification Detail ---")
                print("Message: \(message)")
                print("Status: \(status)")
                print("Date: \(date)")
                print("Receiver ID: \(receiverID)")
                print("Triggered By: \(triggeredBy)")
            }
        }
    }
}
