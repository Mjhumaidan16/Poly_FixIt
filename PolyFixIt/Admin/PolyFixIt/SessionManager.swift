import UIKit
import FirebaseAuth


final class SessionManager {

    static let shared = SessionManager()

    /// Inactivity timeout (seconds).
    private let timeoutSeconds: TimeInterval = 3000000

    /// How often we check inactivity (seconds).
    private let checkInterval: TimeInterval = 1

    private var lastActivity = Date()
    private var timer: DispatchSourceTimer?
    private var isLoggingOut = false

    private init() {}

    /// Start (or restart) the inactivity monitoring.
    func start() {
        stop()
        isLoggingOut = false
        lastActivity = Date()

        let queue = DispatchQueue.main
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + checkInterval, repeating: checkInterval)
        t.setEventHandler { [weak self] in
            self?.tick()
        }
        timer = t
        t.resume()
    }

    func stop() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    /// Call on any user interaction.
    func userDidInteract() {
        lastActivity = Date()
    }

    private func tick() {
        guard !isLoggingOut else { return }

        // Only enforce inactivity timeout if an admin session exists.
        // This avoids "logging out" repeatedly while already on the login screen.
        let hasAdminSession = UserDefaults.standard.data(forKey: "loggedInAdmin") != nil
            || Auth.auth().currentUser != nil

        guard hasAdminSession else {
            return
        }

        let idle = Date().timeIntervalSince(lastActivity)
        if idle >= timeoutSeconds {
            forceLogout()
        }
    }

    private func forceLogout() {
        guard !isLoggingOut else { return }
        isLoggingOut = true
        stop()

        // Clear local session cache
        UserDefaults.standard.removeObject(forKey: "loggedInAdmin")

        // Firebase sign out (safe even if already signed out)
        do { try Auth.auth().signOut() } catch { }

        DispatchQueue.main.async {
            self.showAlertThenGoToLogin()
        }
    }

    private func showAlertThenGoToLogin() {
        guard let top = UIApplication.shared.topMostViewController() else {
            goToLogin()
            return
        }

        let alert = UIAlertController(
            title: "Session Expired",
            message: "You were logged out due to inactivity.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.goToLogin()
        })

        if let presented = top.presentedViewController {
            presented.dismiss(animated: false) {
                top.present(alert, animated: true)
            }
        } else {
            top.present(alert, animated: true)
        }
    }

    private func goToLogin() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return
        }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let loginVC = storyboard.instantiateViewController(withIdentifier: "AdminLoginViewController")
        window.rootViewController = loginVC
        window.makeKeyAndVisible()

        // Reset state for next login.
        isLoggingOut = false
        lastActivity = Date()
    }
}

// MARK: - Global touch detection (requires main.swift)

final class AdminApplication: UIApplication {
    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)

        if let touches = event.allTouches,
           touches.contains(where: { $0.phase == .began }) {
            SessionManager.shared.userDidInteract()
        }
    }
}

// MARK: - Helpers

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
