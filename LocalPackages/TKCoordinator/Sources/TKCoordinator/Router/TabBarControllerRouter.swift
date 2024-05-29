import UIKit

public final class TabBarControllerRouter: ContainerViewControllerRouter<UITabBarController> {
  
  public var didSelectItem: ((Int) -> Void)?
  
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
  
  public func insert(viewController: UIViewController, at index: Int) {
    rootViewController.viewControllers?.insert(viewController, at: index)
  }
  
  public func remove(viewController: UIViewController) {
    guard let index = rootViewController.viewControllers?.firstIndex(of: viewController) else { return }
    rootViewController.viewControllers?.remove(at: index)
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
  
  public func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
    guard let index = tabBarController.viewControllers?.firstIndex(of: viewController) else { return }
    didSelectItem?(index)
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
