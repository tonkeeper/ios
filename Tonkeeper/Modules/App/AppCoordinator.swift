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
  
  var blurWindow: UIWindow?
 
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
    guard let windowScene = router.window.windowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    window.windowLevel = UIWindow.Level.statusBar
    window.backgroundColor = .clear
    window.rootViewController = BlurViewController()
    window.makeKeyAndVisible()
    self.blurWindow = window
    window.alpha = .showBlurInitialOpacity
    UIView.animate(withDuration: .showBlurAnimationDuration) {
      window.alpha = 1
    }
  }
  
  func hideBlur() {
    UIView.animate(withDuration: .hideBlurAnimationDuration) {
      self.blurWindow?.alpha = 0
    } completion: { _ in
      self.blurWindow = nil
      self.router.window.makeKeyAndVisible()
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
