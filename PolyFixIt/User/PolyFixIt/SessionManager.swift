import UIKit
import FirebaseAuth

/// Global session / inactivity manager.
///
/// - Tracks last user interaction.
/// - If the user is authenticated (Firebase `Auth.auth().currentUser != nil`) and idle for 30 seconds, it:
///   1) shows an alert
///   2) signs out of Firebase
///   3) returns to `UserLoginViewController`
final class SessionManager {

    static let shared = SessionManager()

    private let timeoutSeconds: TimeInterval = 30
    private let checkIntervalSeconds: TimeInterval = 1

    // Use a GCD timer instead of Foundation.Timer.
    // It is less sensitive to run-loop modes and tends to be more reliable
    // across UI interactions.
    private var timer: DispatchSourceTimer?
    private var lastActivity: Date = Date()
    private var isLoggingOut = false

    private init() {}

    /// Starts (or restarts) the inactivity timer.
    /// Safe to call multiple times.
    func start() {
        stop()
        isLoggingOut = false
        lastActivity = Date()

        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + checkIntervalSeconds, repeating: checkIntervalSeconds)
        t.setEventHandler { [weak self] in
            self?.tick()
        }
        timer = t
        t.resume()
    }

    /// Stops the inactivity timer.
    func stop() {
        timer?.cancel()
        timer = nil
    }

    /// Resets the inactivity clock.
    func userDidInteract() {
        lastActivity = Date()
    }

    private func tick() {
        // Only enforce inactivity logout if a user is actually signed in.
        guard Auth.auth().currentUser != nil else {
            // Keep the timer running, but don't count idle time on the login screen.
            lastActivity = Date()
            return
        }

        guard !isLoggingOut else { return }

        let idle = Date().timeIntervalSince(lastActivity)
        if idle >= timeoutSeconds {
            forceLogout()
        }
    }

    private func forceLogout() {
        guard !isLoggingOut else { return }
        isLoggingOut = true
        stop()

        do {
            try Auth.auth().signOut()
        } catch {
            // Even if signOut fails, we still want to return to login.
        }

        DispatchQueue.main.async {
            self.presentLogoutAlertAndReturnToLogin()
        }
    }

    private func presentLogoutAlertAndReturnToLogin() {
        let title = "Session Expired"
        let message = "You were logged out due to inactivity."

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.goToLogin()
        })

        guard let topVC = UIApplication.shared.topMostViewController() else {
            goToLogin()
            return
        }

        // Avoid "already presenting" issues.
        if let presented = topVC.presentedViewController {
            presented.dismiss(animated: false) {
                topVC.present(alert, animated: true)
            }
        } else {
            topVC.present(alert, animated: true)
        }
    }

    /// Resets the app UI back to the login screen.
    /// Uses storyboard identifier "UserLoginViewController" (present in your Main.storyboard).
    private func goToLogin() {
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
            isLoggingOut = false
            start()
            return
        }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        // Prefer the known storyboard ID for login.
        let loginVC = storyboard.instantiateViewController(withIdentifier: "UserLoginViewController")

        window.rootViewController = loginVC
        window.makeKeyAndVisible()

        // Reset state so future logins will work normally.
        isLoggingOut = false
        lastActivity = Date()
        start()
    }
}

/// Custom UIApplication used to detect touches anywhere in the app.
/// This enables real inactivity tracking without adding code to every view controller.
final class PolyFixApplication: UIApplication {
    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)

        // Any new touch counts as activity.
        if let touches = event.allTouches,
           touches.contains(where: { $0.phase == .began }) {
            SessionManager.shared.userDidInteract()
        }
    }
}

extension UIApplication {
    /// Returns the top-most view controller for alert presentation.
    func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC = base ?? connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController

        if let nav = baseVC as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }

        if let tab = baseVC as? UITabBarController, let selected = tab.selectedViewController {
            return topMostViewController(base: selected)
        }

        if let presented = baseVC?.presentedViewController {
            return topMostViewController(base: presented)
        }

        return baseVC
    }
}
