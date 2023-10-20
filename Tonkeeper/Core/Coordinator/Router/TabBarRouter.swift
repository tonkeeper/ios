//
//  TabBarRouter.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class TabBarRouter: Router<UITabBarController> {
  
  override init(rootViewController: UITabBarController) {
    super.init(rootViewController: rootViewController)
    rootViewController.delegate = self
  }
  
  func set(presentables: [Presentable],
           options: RouteOptions = .default,
           completion: (() -> Void)? = nil) {
    rootViewController.set(viewControllers: presentables.map { $0.viewController },
                           options: options,
                           completion: completion)
  }
  
  func select(presentable: Presentable,
              options: RouteOptions = .default,
              completion: (() -> Void)? = nil) {
    rootViewController.select(viewController: presentable.viewController,
                              options: options,
                              completion: completion)
  }
  
  func select(index: Int,
              options: RouteOptions = .default,
              completion: (() -> Void)? = nil) {
    rootViewController.select(index: index,
                              options: options,
                              completion: completion)
  }
}

extension TabBarRouter: UITabBarControllerDelegate {
  func tabBarController(_ tabBarController: UITabBarController,
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
