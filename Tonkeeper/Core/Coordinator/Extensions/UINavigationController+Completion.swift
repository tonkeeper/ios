//
//  UINavigationController+Completion.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

extension UINavigationController {
  func pushViewController(_ viewController: UIViewController,
                          options: RouteOptions,
                          completion: (() -> Void)? = nil) {
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    pushViewController(viewController,
                       animated: options.isAnimated)
    CATransaction.commit()
  }
  
  func popViewController(options: RouteOptions,
                         completion: (() -> Void)? = nil) {
    CATransaction.begin()
    CATransaction.setCompletionBlock {
      completion?()
    }
    popViewController(animated: options.isAnimated)
    CATransaction.commit()
  }
  
  func popToRootViewController(options: RouteOptions,
                               completion: (() -> Void)? = nil) {
    CATransaction.begin()
    CATransaction.setCompletionBlock {
      completion?()
    }
    popToRootViewController(animated: options.isAnimated)
    CATransaction.commit()
  }
  
  func popToViewController(_ viewController: UIViewController,
                           options: RouteOptions,
                           completion: (() -> Void)? = nil) {
    CATransaction.begin()
    CATransaction.setCompletionBlock {
      completion?()
    }
    popToViewController(viewController,
                        animated: options.isAnimated)
    CATransaction.commit()
  }
  
  func setViewControllers(_ viewControllers: [UIViewController],
                          options: RouteOptions,
                          completion: (() -> Void)? = nil) {
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    setViewControllers(viewControllers,
                       animated: options.isAnimated)
    CATransaction.commit()
  }
}
