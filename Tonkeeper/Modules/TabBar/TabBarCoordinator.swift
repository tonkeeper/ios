//
//  TabBarCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class TabBarCoordinator: Coordinator<TabBarRouter> {
  
  private let assembly: TabBarAssembly
  
  private let walletCoordinator: WalletCoordinator
  
  init(router: TabBarRouter,
       assembly: TabBarAssembly) {
    self.assembly = assembly
    self.walletCoordinator = assembly.walletCoordinator()
    super.init(router: router)
  }
  
  override func start() {
    setupTabBarItems()
    
    let presentables = [walletCoordinator].map { $0.router.rootViewController }
    router.set(presentables: presentables)
  }
}

private extension TabBarCoordinator {
  func setupTabBarItems() {
    walletCoordinator.router.rootViewController.tabBarItem.image = .Icons.TabBar.wallet?.withRenderingMode(.alwaysTemplate)
    walletCoordinator.router.rootViewController.tabBarItem.title = "Wallet"
  }
}
