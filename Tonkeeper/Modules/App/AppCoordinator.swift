//
//  AppCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit
import TKCore
import WalletCore
import WidgetKit

final class AppCoordinator: Coordinator<WindowRouter> {
  
  private let appAssembly: AppAssembly
  private let appStateTracker: AppStateTracker
  
  private var blurViewController: BlurViewController?
 
  init(router: WindowRouter,
       appAssembly: AppAssembly,
       appStateTracker: AppStateTracker) {
    self.appAssembly = appAssembly
    self.appStateTracker = appStateTracker
    super.init(router: router)
    appStateTracker.addObserver(self)
    Task {
      await appAssembly.rootAssembly.walletCoreAssembly.configurationController.loadConfiguration()
    }
  }
  
  override func start() {
    let coordinator = appAssembly.rootCoordinator()
    coordinator.output = self
    router.setRoot(presentable: coordinator.router.rootViewController)
    addChild(coordinator)
    coordinator.start()
  }
}

private extension AppCoordinator {
  func showBlur() {
    guard self.blurViewController == nil else { return }
    let blurViewController = BlurViewController()
    self.blurViewController = blurViewController
    
    self.router.window.addSubview(blurViewController.view)
    blurViewController.view.frame = self.router.window.bounds
    
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

extension AppCoordinator: AppStateTrackerObserver {
  func didUpdateState(_ state: AppStateTracker.State) {
    switch state {
    case .becomeActive:
      hideBlur()
    case .resignActive:
      showBlur()
      WidgetCenter.shared.reloadTimelines(ofKind: "RateWidget")
      WidgetCenter.shared.reloadTimelines(ofKind: "RateChartWidget")
      WidgetCenter.shared.reloadTimelines(ofKind: "BalanceWidget")
    default:
      return
    }
  }
}

extension AppCoordinator: RootCoordinatorOutput {
  func rootCoordinatorDidStartBiometry(_ coordinator: RootCoordinator) {
    showBlur()
  }
  
  func rootCoordinatorDidFinishBiometry(_ coordinator: RootCoordinator) {
    hideBlur()
  }
}

private extension TimeInterval {
  static let showBlurAnimationDuration: TimeInterval = 0.1
  static let hideBlurAnimationDuration: TimeInterval = 0.2
}

private extension CGFloat {
  static let showBlurInitialOpacity: CGFloat = 0.3
}
