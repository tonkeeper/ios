import UIKit

/// What the liquid glass headers share when they hand their content to the system bar of the
/// navigation controller their screen is in.
extension UIView {
    /// The view controller the navigation controller shows: the view may sit in a child of it, and
    /// only the shown controller's navigation item reaches the bar. A bottom sheet's navigation
    /// controller only hosts the sheet, which draws its own header, so it is no stack.
    var tkStackViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let viewController = current as? UIViewController,
               let navigationController = viewController.parent as? UINavigationController
            {
                return navigationController.viewControllers.first is TKBottomSheetViewController ? nil : viewController
            }
            responder = current.next
        }
        return nil
    }

    /// The stacks these screens live in usually hide the system bar, so the screen on top shows it.
    /// Without animation: the screen itself hid the bar animated in `viewWillAppear`, and a second
    /// animation in the same transition makes the bar overshoot and snap back once it ends.
    func tkShowSystemNavigationBarIfOnTop() {
        guard let viewController = tkStackViewController,
              let navigationController = viewController.navigationController,
              navigationController.topViewController === viewController,
              navigationController.isNavigationBarHidden
        else { return }
        navigationController.setNavigationBarHidden(false, animated: false)
    }
}

public extension UIViewController {
    /// For a screen whose header goes to the system bar under liquid glass, called from `viewWillAppear`:
    /// shows the bar there, so the change rides the transition and a swipe back neither drops the bar nor
    /// brings it back once the swipe ends. Otherwise the screen draws its own header, so the bar is hidden.
    func tkUpdateNavigationBarForHeader(animated: Bool) {
        guard let navigationController else { return }
        let isInStack = parent === navigationController
            && !(navigationController.viewControllers.first is TKBottomSheetViewController)
        let usesSystemBar = TKLiquidGlass.isEnabled && isInStack
        if usesSystemBar {
            // The header configures the item only once SwiftUI renders it, after the bar starts to show, and
            // the first frames would show the default appearance and the system back button.
            navigationItem.tkConfigureSystemBarAppearance(backgroundColor: nil)
        }
        // A stack being presented brings its root's bar with it, not in an animation of its own.
        navigationController.setNavigationBarHidden(
            !usesSystemBar,
            animated: animated && !navigationController.isBeingPresented
        )
    }
}

extension UINavigationItem {
    /// - Parameter backgroundColor: nil keeps the bar transparent, so content scrolls under the glass.
    func tkConfigureSystemBarAppearance(backgroundColor: UIColor?) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = backgroundColor
        appearance.titleTextAttributes = [
            .font: TKTextStyle.h3.font,
            .foregroundColor: UIColor.Text.primary,
        ]
        standardAppearance = appearance
        scrollEdgeAppearance = appearance
        compactAppearance = appearance
        largeTitleDisplayMode = .never
        // The screen's own back button, if any, is among its items.
        hidesBackButton = true
    }
}
