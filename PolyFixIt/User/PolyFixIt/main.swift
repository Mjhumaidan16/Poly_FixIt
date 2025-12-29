import UIKit

// Entry point for the app.
// We use a custom UIApplication subclass (PolyFixApplication) to catch user interaction globally
// and reset the inactivity timer without adding code to every view controller.
_ = UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    NSStringFromClass(PolyFixApplication.self),
    NSStringFromClass(AppDelegate.self)
)
