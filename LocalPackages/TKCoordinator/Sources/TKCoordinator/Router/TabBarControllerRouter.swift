import UIKit

public final class TabBarControllerRouter: ContainerViewControllerRouter<UITabBarController> {
  
  public override init(rootViewController: UITabBarController) {
    super.init(rootViewController: rootViewController)
    rootViewController.delegate = self
  }
  
  public func set(viewControllers: [UIViewController],
           animated: Bool,
           completion: (() -> Void)? = nil) {
    rootViewController.set(
      viewControllers: viewControllers,
      animated: animated,
      completion: completion)
  }
  
  public func select(viewController: UIViewController,
              completion: (() -> Void)? = nil) {
    rootViewController.select(
      viewController: viewController, 
      completion: completion
    )
  }
  
  public func select(index: Int, completion: (() -> Void)? = nil) {
    rootViewController.select(
      index: index, 
      completion: completion
    )
  }
}

extension TabBarControllerRouter: UITabBarControllerDelegate {
  public func tabBarController(_ tabBarController: UITabBarController,
                        shouldSelect viewController: UIViewController) -> Bool {
    if tabBarController.viewControllers?[tabBarController.selectedIndex] == viewController {
      (viewController as? ScrollViewController)?.scrollToTop()
    }
    return true
  }
}

protocol ScrollViewController: UIViewController {
  func scrollToTop()
}

extension UINavigationController: ScrollViewController {
  func scrollToTop() {
    (topViewController as? ScrollViewController)?.scrollToTop()
  }
}
