//
//  UITabBarController+Completions.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import Foundation

import UIKit

extension UITabBarController {
  func set(viewControllers: [UIViewController],
           options: RouteOptions,
           completion: (() -> Void)? = nil) {
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    setViewControllers(viewControllers,
                       animated: options.isAnimated)
    CATransaction.commit()
  }
  
  func select(viewController: UIViewController,
              options: RouteOptions,
              completion: (() -> Void)? = nil) {
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    selectedViewController = viewController
    CATransaction.commit()
  }
  
  func select(index: Int,
              options: RouteOptions,
              completion: (() -> Void)? = nil) {
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    selectedIndex = index
    CATransaction.commit()
  }
}
