//
//  AppDelegate.swift
//  SignIn
//
//  Created by BP-36-201-18 on 13/12/2025.
//

import UIKit
import Firebase
import FirebaseFirestore
import Cloudinary

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static var cloudinary: CLDCloudinary!
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        configureCloudinary()
        
        let db = Firestore.firestore()
        print("Firestore instance is initialized: \(db)")
        // Override point for customization after application launch.
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    private func configureCloudinary() {
        guard
            let cloudName = Bundle.main.object(forInfoDictionaryKey: "CLOUDINARY_CLOUD_NAME") as? String,
            let apiKey = Bundle.main.object(forInfoDictionaryKey: "CLOUDINARY_API_KEY") as? String
        else {
            fatalError("❌ Cloudinary keys missing from Info.plist")
        }
        
        let config = CLDConfiguration(
            cloudName: cloudName,
            apiKey: apiKey, // We still need the API key for unsigned uploads
            secure: true
        )
        
        AppDelegate.cloudinary = CLDCloudinary(configuration: config)
    }
}
