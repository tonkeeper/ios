import UIKit

public final class NavigationControllerRouter: ContainerViewControllerRouter<UINavigationController> {
    private var onPopClosures = [UIViewController: () -> Void]()

    override public init(rootViewController: UINavigationController) {
        super.init(rootViewController: rootViewController)
        rootViewController.delegate = self
    }

    public func push(
        viewController: UIViewController,
        animated: Bool = true,
        onPopClosures: (() -> Void)? = nil,
        completion: (() -> Void)? = nil
    ) {
        self.onPopClosures[viewController] = onPopClosures
        rootViewController.pushViewController(
            viewController,
            animated: animated,
            completion: completion
        )
    }

    public func pop(
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        rootViewController.popViewController(
            animated: animated,
            completion: completion
        )
    }

    public func popToRoot(
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        rootViewController.popToRootViewController(
            animated: animated,
            completion: completion
        )
    }
}

extension NavigationControllerRouter: UINavigationControllerDelegate {
    public func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        // Sweep every tracked controller instead of reading transitionCoordinator's
        // .from: multi-pop transitions (popToRoot, popTo, setViewControllers) report
        // only the top controller, and non-animated ones have no coordinator at all —
        // intermediate screens would keep their closures forever.
        guard !onPopClosures.isEmpty else { return }
        let stack = navigationController.viewControllers
        let poppedViewControllers = onPopClosures.keys.filter { !stack.contains($0) }
        for poppedViewController in poppedViewControllers {
            onPopClosures.removeValue(forKey: poppedViewController)?()
        }
    }
}
