//
//  AppCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit
import TKCore
import WalletCoreKeeper
import WidgetKit

final class AppCoordinator: Coordinator<WindowRouter> {
  
  private let appAssembly: AppAssembly
  private let appStateTracker: AppStateTracker
  
  private var rootCoordinator: RootCoordinator?
  
  private var blurViewController: BlurViewController?
  
  private var blurWindow: UIWindow?
 
  init(router: WindowRouter,
       appAssembly: AppAssembly,
       appStateTracker: AppStateTracker) {
    self.appAssembly = appAssembly
    self.appStateTracker = appStateTracker
    super.init(router: router)
    appStateTracker.addObserver(self)
    Task {
      try await appAssembly.walletCoreAssembly.knownAccounts.loadAccounts()
      _ = await appAssembly.walletCoreAssembly.configurationController.loadConfiguration()
      _ = try await appAssembly.walletCoreAssembly.fiatMethodsController().loadFiatMethods()
    }
  }

  override func start(deeplink: Deeplink?) {
    let coordinator = appAssembly.rootCoordinator()
    self.rootCoordinator = coordinator
    coordinator.output = self
    router.setRoot(presentable: coordinator.router.rootViewController)
    addChild(coordinator)
    coordinator.start(deeplink: deeplink)
  }
  
  override func handleDeeplink(_ deeplink: Deeplink) {
    rootCoordinator?.handleDeeplink(deeplink)
  }
}

private extension AppCoordinator {
  func showBlur() {
    guard let scene = UIApplication.keyWindowScene else { return }
    let window = UIWindow(windowScene: scene)
    let blurViewController = BlurViewController()
    window.rootViewController = blurViewController
    self.blurWindow = window
    window.makeKeyAndVisible()
    blurViewController.view.alpha = .showBlurInitialOpacity
    UIView.animate(withDuration: .showBlurAnimationDuration) {
      blurViewController.view.alpha = 1
    }
  }
  
  func hideBlur() {
    let blurWindow = self.blurWindow
    
    UIView.animate(withDuration: .hideBlurAnimationDuration) {
      blurWindow?.rootViewController?.view.alpha = 0
    } completion: { _ in
      if blurWindow === self.blurWindow {
        self.blurWindow = nil
      }
    }
  }
}

extension AppCoordinator: AppStateTrackerObserver {
  func didUpdateState(_ state: AppStateTracker.State) {
    switch state {
    case .resign:
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
