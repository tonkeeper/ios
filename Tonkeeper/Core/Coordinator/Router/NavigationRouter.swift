//
//  NavigationRouter.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class NavigationRouter: Router<UINavigationController> {
  private var dismissClosures = [UIViewController: () -> Void]()
  
  override init(rootViewController: UINavigationController) {
    super.init(rootViewController: rootViewController)
    rootViewController.delegate = self
  }
  
  func push(presentable: Presentable,
            options: RouteOptions = .default,
            dismiss: (() -> Void)? = nil,
            completion: (() -> Void)? = nil) {
    dismissClosures[presentable.viewController] = completion
    rootViewController.pushViewController(presentable.viewController,
                                          options: options,
                                          completion: completion)
  }

  func pop(options: RouteOptions = .default,
           completion: (() -> Void)? = nil) {
      rootViewController.popViewController(options: options, completion: completion)
  }

  func popToRoot(options: RouteOptions = .default,
                 completion: (() -> Void)? = nil) {
    rootViewController.popToRootViewController(options: options, completion: completion)
  }
  
  func popTo(presentable: Presentable,
             options: RouteOptions = .default,
             completion: (() -> Void)? = nil) {
    rootViewController.popToViewController(presentable.viewController,
                                           options: options,
                                           completion: completion)
  }
  
  func setPresentables(_ presentables: [(Presentable, dismiss: (() -> Void)?)],
                       options: RouteOptions = .default,
                       completion: (() -> Void)? = nil) {
    let viewControllers = presentables.map { $0.0.viewController }
    presentables.forEach {
      dismissClosures[$0.0.viewController] = $0.1
    }
    rootViewController.setViewControllers(viewControllers,
                                          options: options,
                                          completion: completion)
  }
}

extension NavigationRouter: UINavigationControllerDelegate {
  func navigationController(_ navigationController: UINavigationController,
                            didShow viewController: UIViewController,
                            animated: Bool) {
    guard let fromViewController = navigationController.transitionCoordinator?.viewController(forKey: .from),
          !navigationController.viewControllers.contains(fromViewController) else {
      return
    }
    
    dismissClosures[fromViewController]?()
    dismissClosures.removeValue(forKey: fromViewController)
  }
}
