import UIKit
import FirebaseAuth

/// Global inactivity-based session timeout manager.
///
/// How it works:
/// - A custom UIApplication subclass (`TechnicianApplication`) detects touches anywhere in the app.
/// - Each touch calls `SessionManager.shared.userDidInteract()`.
/// - A GCD timer checks inactivity and forces logout after `timeoutSeconds`.
final class SessionManager {

    static let shared = SessionManager()

    /// Inactivity timeout (seconds).
    // Inactivity timeout (seconds). Change to 30 if you prefer a full 30-second session.
    private let timeoutSeconds: TimeInterval = 25

    private var timer: DispatchSourceTimer?
    private var lastActivity: Date = Date()
    private var isLoggingOut = false

    private init() {}

    /// Start (or restart) the inactivity timer.
    func start() {
        stop()
        isLoggingOut = false
        lastActivity = Date()

        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 1, repeating: 1)
        t.setEventHandler { [weak self] in
            self?.tick()
        }
        timer = t
        t.resume()
    }

    /// Stop the inactivity timer.
    func stop() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    /// Mark the session as active (reset inactivity).
    func userDidInteract() {
        lastActivity = Date()
    }

    private func tick() {
        // Only enforce timeout when a Firebase user exists (i.e., logged in).
        guard Auth.auth().currentUser != nil else { return }
        guard !isLoggingOut else { return }

        let idle = Date().timeIntervalSince(lastActivity)
        if idle >= timeoutSeconds {
            forceLogout(reason: "You were logged out due to inactivity.")
        }
    }

    /// Force logout immediately.
    func forceLogout(reason: String) {
        guard !isLoggingOut else { return }
        isLoggingOut = true
        stop()

        // Clear local cached tech info
        UserDefaults.standard.removeObject(forKey: "loggedInTech")

        // Firebase sign out
        do { try Auth.auth().signOut() } catch { /* ignore */ }

        DispatchQueue.main.async {
            self.presentLogoutAlertAndReturnToLogin(message: reason)
        }
    }

    private func presentLogoutAlertAndReturnToLogin(message: String) {
        // If we're already on the login screen, just reset activity and restart.
        let top = UIApplication.shared.topMostViewController()

        let alert = UIAlertController(
            title: "Session Expired",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.goToLoginRoot()
        })

        guard let presenter = top else {
            goToLoginRoot()
            return
        }

        if let presented = presenter.presentedViewController {
            presented.dismiss(animated: false) {
                presenter.present(alert, animated: true)
            }
        } else {
            presenter.present(alert, animated: true)
        }
    }

    private func goToLoginRoot() {
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first(where: { $0.isKeyWindow })
        else { return }

        // Tech login is the initial VC of Main.storyboard in this project.
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let loginVC = storyboard.instantiateInitialViewController() ?? UIViewController()

        window.rootViewController = loginVC
        window.makeKeyAndVisible()

        // Reset state for next login.
        lastActivity = Date()
        isLoggingOut = false
        start()
    }
}

/// Custom UIApplication to detect global touches and reset the inactivity timer.
final class TechnicianApplication: UIApplication {
    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)

        if let touches = event.allTouches,
           touches.contains(where: { $0.phase == .began }) {
            SessionManager.shared.userDidInteract()
        }
    }
}

// MARK: - Top-most VC helper

extension UIApplication {
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
