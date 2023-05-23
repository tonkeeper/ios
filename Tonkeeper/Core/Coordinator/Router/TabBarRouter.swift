//
//  TabBarRouter.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class TabBarRouter: Router<UITabBarController> {
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
