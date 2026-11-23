import UIKit

public extension UIViewController {
    /// What to present for a screen shown modally on its own. Under liquid glass its header lives in a
    /// navigation controller's system bar, so the screen goes into one that takes over its sheet
    /// presentation; otherwise the screen itself.
    ///
    /// `dismiss` reaches the navigation controller's presentation; a presentation delegate goes through
    /// `tkPresentationController`.
    func tkLiquidGlassModal() -> UIViewController {
        guard TKLiquidGlass.isEnabled, navigationController == nil else { return self }

        let style = modalPresentationStyle
        let sourceSheet = style == .pageSheet || style == .formSheet ? sheetPresentationController : nil
        let isModal = isModalInPresentation
        let presentationDelegate = presentationController?.delegate

        let navigationController = TKNavigationController(rootViewController: self)
        navigationController.configureTransparentAppearance()
        navigationController.modalPresentationStyle = style
        navigationController.isModalInPresentation = isModal
        if let presentationDelegate {
            navigationController.presentationController?.delegate = presentationDelegate
        }
        if let sourceSheet, let sheet = navigationController.sheetPresentationController {
            sheet.detents = sourceSheet.detents
            sheet.selectedDetentIdentifier = sourceSheet.selectedDetentIdentifier
            sheet.prefersGrabberVisible = sourceSheet.prefersGrabberVisible
            sheet.prefersScrollingExpandsWhenScrolledToEdge = sourceSheet.prefersScrollingExpandsWhenScrolledToEdge
            sheet.preferredCornerRadius = sourceSheet.preferredCornerRadius
            sheet.largestUndimmedDetentIdentifier = sourceSheet.largestUndimmedDetentIdentifier
        }
        return navigationController
    }

    /// The presentation that shows this screen: its navigation controller's when the screen is that
    /// controller's root. The screen's own `presentationController` can be one UIKit made for it before it
    /// was embedded (on the first read of `sheetPresentationController`), which is never presented, so a
    /// delegate set there never hears of a swipe-down.
    var tkPresentationController: UIPresentationController? {
        if let navigationController, navigationController.viewControllers.first === self {
            return navigationController.presentationController
        }
        return presentationController
    }
}
