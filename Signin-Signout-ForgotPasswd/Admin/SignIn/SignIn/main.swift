import UIKit

// Entry point that registers our custom UIApplication subclass (AdminApplication)
// so we can detect taps globally and reset inactivity timeout.
_ = UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    NSStringFromClass(AdminApplication.self),
    NSStringFromClass(AppDelegate.self)
)
