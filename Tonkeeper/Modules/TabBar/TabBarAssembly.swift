//
//  TabBarAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class TabBarAssembly {
  
  lazy var walletAssembly = WalletAssembly()
  lazy var activityAssembly = ActivityAssembly()
  
  func walletCoordinator() -> WalletCoordinator {
    let navigationController = UINavigationController()
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = WalletCoordinator(router: router,
                                        walletAssembly: walletAssembly)
    return coordinator
  }
  
  func activityCoordinator() -> ActivityCoordinator {
    let navigationController = UINavigationController()
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = ActivityCoordinator(router: router,
                                        assembly: activityAssembly)
    return coordinator
  }
}
