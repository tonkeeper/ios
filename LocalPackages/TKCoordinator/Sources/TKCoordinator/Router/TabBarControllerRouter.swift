import UIKit

public final class TabBarControllerRouter: ContainerViewControllerRouter<UITabBarController> {
    public var didSelectItem: ((Int) -> Void)?
    public var transitionAnimator: ((_ fromIndex: Int, _ toIndex: Int) -> (any UIViewControllerAnimatedTransitioning)?)?

    override public init(rootViewController: UITabBarController) {
        super.init(rootViewController: rootViewController)
        rootViewController.delegate = self
    }
}

extension TabBarControllerRouter: UITabBarControllerDelegate {
    public func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        if tabBarController.viewControllers?[tabBarController.selectedIndex] == viewController {
            (viewController as? ScrollViewController)?.scrollToTop()
        }
        return true
    }

    public func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard let index = tabBarController.viewControllers?.firstIndex(of: viewController) else { return }
        didSelectItem?(index)
    }

    public func tabBarController(
        _ tabBarController: UITabBarController,
        animationControllerForTransitionFrom fromVC: UIViewController,
        to toVC: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        guard let transitionAnimator,
              let viewControllers = tabBarController.viewControllers,
              let fromIndex = viewControllers.firstIndex(of: fromVC),
              let toIndex = viewControllers.firstIndex(of: toVC)
        else { return nil }
        return transitionAnimator(fromIndex, toIndex)
    }
}

public protocol ScrollViewController: UIViewController {
    func scrollToTop()
}

extension UINavigationController: ScrollViewController {
    public func scrollToTop() {
        (topViewController as? ScrollViewController)?.scrollToTop()
    }
}
