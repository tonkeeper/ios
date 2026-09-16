import UIKit

public protocol TKOwnHeaderScreen: UIViewController {}

public extension TKOwnHeaderScreen {
    func hideNavigationBar(animated: Bool) {
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    /// The navigation stack is already mutated by the time a screen disappears, so
    /// `topViewController` is the destination of the transition: the bar comes back only for a
    /// screen that has no header of its own, in either direction.
    func restoreNavigationBar(animated: Bool) {
        guard let navigationController,
              !(navigationController.topViewController is TKOwnHeaderScreen)
        else { return }
        navigationController.setNavigationBarHidden(false, animated: animated)
    }
}
