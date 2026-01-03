import UIKit
import Firebase
import GoogleSignIn
import Cloudinary
// NOTE: @main is intentionally removed because the project now uses main.swift
// to set a custom UIApplication subclass for global inactivity tracking.
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static var cloudinary: CLDCloudinary!
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        configureCloudinary()
        
        let db = Firestore.firestore()
        // Set up Google Sign-In with the client ID from GoogleService-Info.plist
        if let clientID = FirebaseApp.app()?.options.clientID {
            let configuration = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = configuration
        }
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {
        // Handle discarded scene sessions if needed
    }

    // MARK: - Google Sign-In URL Handling
    // This method is required to handle the redirect URL when Google Sign-In completes
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Start/refresh the inactivity timer whenever the app becomes active.
        SessionManager.shared.start()
        SessionManager.shared.userDidInteract()
    }
    
    private func configureCloudinary() {
        guard
            let cloudName = Bundle.main.object(forInfoDictionaryKey: "CLOUDINARY_CLOUD_NAME") as? String,
            let apiKey = Bundle.main.object(forInfoDictionaryKey: "CLOUDINARY_API_KEY") as? String
        else {
            fatalError(" Cloudinary keys missing from Info.plist")
        }
        
        let config = CLDConfiguration(
            cloudName: cloudName,
            apiKey: apiKey, // We still need the API key for unsigned uploads
            secure: true
        )
        
        AppDelegate.cloudinary = CLDCloudinary(configuration: config)
    }
}
