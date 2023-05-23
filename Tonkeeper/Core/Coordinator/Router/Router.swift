//
//  Router.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

protocol RouterProtocol<RootViewController> {
  associatedtype RootViewController: UIViewController
  var rootViewController: RootViewController { get }
}

class Router<RootViewController: UIViewController>: NSObject, RouterProtocol {
  let rootViewController: RootViewController
  
  init(rootViewController: RootViewController) {
    self.rootViewController = rootViewController
  }
  
  func present(_ presentable: Presentable,
               options: RouteOptions = .default,
               completion: (() -> Void)? = nil) {
    rootViewController.present(presentable.viewController,
                               animated: options.isAnimated,
                               completion: completion)
  }
  
  func dismiss(options: RouteOptions = .default,
               completion: (() -> Void)? = nil) {
    rootViewController.dismiss(animated: options.isAnimated,
                               completion: completion)
  }
}
