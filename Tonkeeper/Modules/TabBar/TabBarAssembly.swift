//
//  TabBarAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class TabBarAssembly {
  
  let coreAssembly: CoreAssembly
  let walletCoreAssembly: WalletCoreAssembly
  
  lazy var walletAssembly = WalletAssembly(
    walletCoreAssembly: walletCoreAssembly,
    sendAssembly: SendAssembly(walletCoreAssembly: walletCoreAssembly),
    receiveAssembly: receiveAssembly,
    buyAssembly: BuyAssembly(),
    inAppBrowserAssembly: InAppBrowserAssembly()
  )
  lazy var activityAssembly = ActivityAssembly(receiveAssembly: receiveAssembly,
                                               collectibleAssembly: collectibleAssembly,
                                               walletCoreAssembly: walletCoreAssembly)
  lazy var browserAssembly = BrowserAssembly()
  lazy var settingsAssembly = SettingsAssembly()
  lazy var receiveAssembly = ReceiveAssembly(walletCoreAssembly: walletCoreAssembly)
  lazy var collectibleAssembly = CollectibleAssembly(walletCoreAssembly: walletCoreAssembly)
  
  init(coreAssembly: CoreAssembly,
       walletCoreAssembly: WalletCoreAssembly) {
    self.coreAssembly = coreAssembly
    self.walletCoreAssembly = walletCoreAssembly
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
    let navigationController = UINavigationController()
    navigationController.configureDefaultAppearance()
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = SettingsCoordinator(router: router,
                                          assembly: settingsAssembly)
    return coordinator
  }
}
