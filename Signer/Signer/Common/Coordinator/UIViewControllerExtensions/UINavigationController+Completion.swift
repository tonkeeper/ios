import UIKit

extension UINavigationController {
  func pushViewController(_ viewController: UIViewController,
                          animated: Bool,
                          completion: (() -> Void)? = nil) {
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    pushViewController(viewController,
                       animated: animated)
    CATransaction.commit()
  }
  
  func popViewController(animated: Bool,
                         completion: (() -> Void)? = nil) {
    CATransaction.begin()
    CATransaction.setCompletionBlock {
      completion?()
    }
    popViewController(animated: animated)
    CATransaction.commit()
  }
  
  func popToRootViewController(animated: Bool,
                               completion: (() -> Void)? = nil) {
    CATransaction.begin()
    CATransaction.setCompletionBlock {
      completion?()
    }
    popToRootViewController(animated: animated)
    CATransaction.commit()
  }
  
  func popToViewController(_ viewController: UIViewController,
                           animated: Bool,
                           completion: (() -> Void)? = nil) {
    CATransaction.begin()
    CATransaction.setCompletionBlock {
      completion?()
    }
    popToViewController(viewController,
                        animated: animated)
    CATransaction.commit()
  }
  
  func setViewControllers(_ viewControllers: [UIViewController],
                          animated: Bool,
                          completion: (() -> Void)? = nil) {
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    setViewControllers(viewControllers,
                       animated: animated)
    CATransaction.commit()
  }
}

