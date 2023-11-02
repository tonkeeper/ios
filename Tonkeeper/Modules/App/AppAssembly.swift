//
//  AppAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit
import TKCore

final class AppAssembly {
  let coreAssembly = CoreAssembly()
  lazy var walletCoreAssembly = WalletCoreAssembly(coreAssembly: coreAssembly)
  
  func rootCoordinator() -> RootCoordinator {
    let navigationController = NavigationController()
    navigationController.configureTransparentAppearance()
    navigationController.setNavigationBarHidden(true, animated: false)
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = RootCoordinator(
      router: router,
      assembly: .init(
        coreAssembly: coreAssembly,
        walletCoreAssembly: walletCoreAssembly)
    )
    return coordinator
  }
}
