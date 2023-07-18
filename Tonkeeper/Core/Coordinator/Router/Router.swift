//
//  Router.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

protocol RouterProtocol {}

class Router<RootViewController: UIViewController>: NSObject, RouterProtocol, UIAdaptivePresentationControllerDelegate {
  private var dismissClosure: (() -> Void)?
  
  let rootViewController: RootViewController
  
  init(rootViewController: RootViewController) {
    self.rootViewController = rootViewController
  }
  
  func present(_ presentable: Presentable,
               options: RouteOptions = .default,
               completion: (() -> Void)? = nil,
               dismiss: (() -> Void)? = nil) {
    dismissClosure = dismiss
    presentable.viewController.presentationController?.delegate = self
    rootViewController.present(presentable.viewController,
                               animated: options.isAnimated,
                               completion: completion)
  }
  
  func dismiss(options: RouteOptions = .default,
               completion: (() -> Void)? = nil) {
    rootViewController.dismiss(animated: options.isAnimated,
                               completion: completion)
  }
  
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    presentationController.presentingViewController.view.isUserInteractionEnabled = true
    dismissClosure?()
  }
  
  func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
    presentationController.presentingViewController.view.isUserInteractionEnabled = false
  }
}
