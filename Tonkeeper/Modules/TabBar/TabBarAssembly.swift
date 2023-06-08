//
//  TabBarAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class TabBarAssembly {
  
  lazy var walletAssembly = WalletAssembly(
    qrScannerAssembly: QRScannerAssembly(),
    sendAssembly: SendAssembly(qrScannerAssembly: QRScannerAssembly()),
    receiveAssembly: ReceiveAssembly()
  )
  lazy var activityAssembly = ActivityAssembly(receiveAssembly: ReceiveAssembly())
  lazy var browserAssembly = BrowserAssembly()
  lazy var settingsAssembly = SettingsAssembly()
  
  func walletCoordinator() -> WalletCoordinator {
    let navigationController = UINavigationController()
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
    navigationController.setNavigationBarHidden(true, animated: false)
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = ActivityCoordinator(router: router,
                                          assembly: activityAssembly)
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
