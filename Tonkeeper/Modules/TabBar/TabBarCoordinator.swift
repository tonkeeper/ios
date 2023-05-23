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
  private let activityCoordinator: ActivityCoordinator
  
  init(router: TabBarRouter,
       assembly: TabBarAssembly) {
    self.assembly = assembly
    self.walletCoordinator = assembly.walletCoordinator()
    self.activityCoordinator = assembly.activityCoordinator()
    super.init(router: router)
  }
  
  override func start() {
    setupTabBarItems()
    
    let presentables = [
      walletCoordinator,
      activityCoordinator
    ]
      .map { $0.router.rootViewController }
    router.set(presentables: presentables, options: .init(isAnimated: false))
  }
}

private extension TabBarCoordinator {
  func setupTabBarItems() {
    let walletTabBarItem = UITabBarItem(title: "Wallet",
                                        image: .Icons.TabBar.wallet?.withRenderingMode(.alwaysTemplate),
                                        tag: 0)
    walletCoordinator.router.rootViewController.tabBarItem = walletTabBarItem
    
    activityCoordinator.router.rootViewController.tabBarItem.image = .Icons.TabBar.activity?.withRenderingMode(.alwaysTemplate)
    activityCoordinator.router.rootViewController.tabBarItem.title = "Activity"
  }
}
