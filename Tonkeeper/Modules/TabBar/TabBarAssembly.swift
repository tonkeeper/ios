//
//  TabBarAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit
import TKCore
import WalletCore

final class TabBarAssembly {
  
  let coreAssembly: CoreAssembly
  let passcodeAssembly: PasscodeAssembly
  let walletCoreAssembly: WalletCoreAssembly
  
  lazy var walletAssembly = WalletAssembly(
    walletCoreAssembly: walletCoreAssembly,
    sendAssembly: SendAssembly(walletCoreAssembly: walletCoreAssembly),
    receiveAssembly: receiveAssembly,
    inAppBrowserAssembly: InAppBrowserAssembly()
  )
  lazy var activityAssembly = ActivityAssembly(receiveAssembly: receiveAssembly,
                                               collectibleAssembly: collectibleAssembly,
                                               walletCoreAssembly: walletCoreAssembly)
  lazy var browserAssembly = BrowserAssembly()
  lazy var settingsAssembly = SettingsAssembly(walletCoreAssembly: walletCoreAssembly,
                                               passcodeAssembly: passcodeAssembly)
  lazy var receiveAssembly = ReceiveAssembly(walletCoreAssembly: walletCoreAssembly)
  lazy var collectibleAssembly = CollectibleAssembly(walletCoreAssembly: walletCoreAssembly,
                                                     sendAssembly: SendAssembly(walletCoreAssembly: walletCoreAssembly))
  lazy var tonConnectAssembly = TonConnectAssembly(walletCoreAssembly: walletCoreAssembly)
  
  init(coreAssembly: CoreAssembly,
       walletCoreAssembly: WalletCoreAssembly,
       passcodeAssembly: PasscodeAssembly) {
    self.coreAssembly = coreAssembly
    self.walletCoreAssembly = walletCoreAssembly
    self.passcodeAssembly = passcodeAssembly
  }
  
  func walletCoordinator() -> WalletCoordinator {
    let navigationController = NavigationController()
    navigationController.configureDefaultAppearance()
    navigationController.setNavigationBarHidden(true, animated: false)
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = WalletCoordinator(router: router,
                                        walletAssembly: walletAssembly)
    return coordinator
  }
  
  func activityCoordinator() -> ActivityCoordinator {
    let navigationController = UINavigationController()
    navigationController.configureDefaultAppearance()
    navigationController.navigationBar.prefersLargeTitles = true
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = activityAssembly.coordinator(router: router)
    return coordinator
  }
  
  func browserCoordinator() -> BrowserCoordinator {
    let navigationController = UINavigationController()
    navigationController.configureDefaultAppearance()
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = BrowserCoordinator(router: router,
                                         assembly: browserAssembly)
    return coordinator
  }
  
  func settingsCoordinator() -> SettingsCoordinator {
    let navigationController = NavigationController()
    navigationController.navigationBar.prefersLargeTitles = true
    navigationController.configureDefaultAppearance()
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = SettingsCoordinator(router: router,
                                          walletCoreAssembly: walletCoreAssembly,
                                          passcodeAssembly: passcodeAssembly)
    return coordinator
  }
  
  func tonConnectCoordinator(navigationRouter: Router<UIViewController>,
                             parameters: TonConnectParameters,
                             manifest: TonConnectManifest) -> TonConnectCoordinator {
    return tonConnectAssembly.coordinator(router: navigationRouter,
                                          parameters: parameters,
                                          manifest: manifest)
  }
  
  var authEventsDaemon: AuthEventsDaemon {
    AuthEventsDaemon(tonConnectEventsDaemon: walletCoreAssembly.tonConnectEventsDaemon(),
                     appStateTracker: coreAssembly.appStateTracker,
                     reachabilityTracker: coreAssembly.reachabilityTracker)
  }
}
