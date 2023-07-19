//
//  AppCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit
import WalletCore

final class AppCoordinator: Coordinator<WindowRouter> {
  
  private let appAssembly: AppAssembly
  
  private var blurViewController: BlurViewController?
 
  init(router: WindowRouter,
       appAssembly: AppAssembly) {
    self.appAssembly = appAssembly
    super.init(router: router)
  }
  
  override func start() {
    let coordinator = appAssembly.rootCoordinator()
    router.setRoot(presentable: coordinator.router.rootViewController)
    addChild(coordinator)
    coordinator.start()
    startObserveAppStates()
  }
}

private extension AppCoordinator {
  func startObserveAppStates() {
    NotificationCenter.default
      .addObserver(self,
                   selector: #selector(appWillResignActive),
                   name: UIApplication.willResignActiveNotification,
                   object: nil)
    
    NotificationCenter.default
      .addObserver(self,
                   selector: #selector(appDidBecomeActive),
                   name: UIApplication.didBecomeActiveNotification,
                   object: nil)
  }
  
  @objc
  func appWillResignActive() {
    showBlur()
  }
  
  @objc
  func appDidBecomeActive() {
    hideBlur()
  }
  
  func showBlur() {
    let blurViewController = BlurViewController()
    self.blurViewController = blurViewController
    
    router.window.addSubview(blurViewController.view)
    blurViewController.view.frame = router.window.bounds
    
    blurViewController.view.alpha = .showBlurInitialOpacity
    UIView.animate(withDuration: .showBlurAnimationDuration) {
      blurViewController.view.alpha = 1
    }
  }
  
  func hideBlur() {
    UIView.animate(withDuration: .hideBlurAnimationDuration) {
      self.blurViewController?.view.alpha = 0
    } completion: { _ in
      self.blurViewController?.view.removeFromSuperview()
      self.blurViewController = nil
    }
  }
}

private extension TimeInterval {
  static let showBlurAnimationDuration: TimeInterval = 0.1
  static let hideBlurAnimationDuration: TimeInterval = 0.2
}

private extension CGFloat {
  static let showBlurInitialOpacity: CGFloat = 0.3
}
