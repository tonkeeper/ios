import UIKit

extension UITabBarController {
  func set(viewControllers: [UIViewController],
           animated: Bool,
           completion: (() -> Void)? = nil) {
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    setViewControllers(viewControllers,
                       animated: animated)
    CATransaction.commit()
  }
  
  func select(viewController: UIViewController,
              completion: (() -> Void)? = nil) {
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    selectedViewController = viewController
    CATransaction.commit()
  }
  
  func select(index: Int,
              completion: (() -> Void)? = nil) {
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    selectedIndex = index
    CATransaction.commit()
  }
}
