//
//  NotificationViewController.swift
//  PolyFixIt
//
//  Created by BP-36-212-02 on 31/12/2025.
//

import UIKit
import FirebaseFirestore
import AudioToolbox // Necessary for sound/vibration

class NotificationViewController: UIViewController {
    
    let db = Firestore.firestore()
    var listener: ListenerRegistration?

    override func viewDidLoad() {
        super.viewDidLoad()
        startListeningForNotifications()
    }

    func startListeningForNotifications() {
        // 1. Identify the current user (e.g., Technician ID "00")
        let currentUserId = "00"
        let userRef = db.collection("users").document(currentUserId)

        // 2. Setup the Query
        // Monitor notifications where the current user is the receiver and status is unread
        let query = db.collection("notifications")
            .whereField("receiver", isEqualTo: userRef)
            .whereField("status", isEqualTo: "unread")

        // 3. Start Real-time Listening
        listener = query.addSnapshotListener { (querySnapshot, error) in
            guard let snapshot = querySnapshot else {
                print("Error fetching notifications: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            // This block executes immediately whenever a new notification is added
            snapshot.documentChanges.forEach { diff in
                if (diff.type == .added) {
                    let data = diff.document.data()
                    
                    // Extract data from fields
                    let message = data["message"] as? String ?? "No Message"
                    let triggeredBy = data["triggeredby"] as? String ?? "Unknown System"
                    
                    // Show alert on screen
                    self.showAlert(title: "New Alert from \(triggeredBy)", message: message)
                    
                    // Trigger vibration or sound
                    self.playNotificationSound()
                }
            }
        }
    }

    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }

    func playNotificationSound() {
        // Triggers a standard haptic vibration
        UIDevice.vibrate()
    }
}

// Extension for vibration functionality
extension UIDevice {
    static func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}
