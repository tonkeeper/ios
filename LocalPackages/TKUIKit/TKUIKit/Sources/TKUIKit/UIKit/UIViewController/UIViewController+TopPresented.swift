import UIKit

public extension UIViewController {
    func topPresentedViewController() -> UIViewController {
        guard let presented = self.presentedViewController else {
            return self
        }
        return presented.topPresentedViewController()
    }

    /// The controller a new modal has to be presented from. `topPresentedViewController()` alone is
    /// not enough for a controller that sits *under* a modal — a coordinator's own router root, say,
    /// while a bottom sheet is up: it presents nothing itself, so it looks free, but `present`
    /// forwards up to the window's root, which is the one already presenting the sheet and refuses.
    /// Starting from the window makes the topmost modal the presenter instead.
    func modalPresentationSourceViewController() -> UIViewController {
        (view.window?.rootViewController ?? self).topPresentedViewController()
    }
}
