import UIKit

public extension UINavigationController {
    /// The stack a screen has to be pushed on to cover the tab bar, which is the one holding the
    /// tab bar controller itself. `hidesBottomBarWhenPushed` no longer takes the bar out in step
    /// with the transition: it blinks away mid-push and comes back on top of the closing screen.
    /// Returns `self` when there is no tab bar controller above.
    var tabBarHostNavigationController: UINavigationController {
        tabBarController?.navigationController ?? self
    }
}
