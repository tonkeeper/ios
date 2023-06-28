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
  private let browserCoordinator: BrowserCoordinator
  private let settingsCoordinator: SettingsCoordinator
  
  init(router: TabBarRouter,
       assembly: TabBarAssembly) {
    self.assembly = assembly
    self.walletCoordinator = assembly.walletCoordinator()
    self.activityCoordinator = assembly.activityCoordinator()
    self.browserCoordinator = assembly.browserCoordinator()
    self.settingsCoordinator = assembly.settingsCoordinator()
    super.init(router: router)
    walletCoordinator.output = self
  }
  
  override func start() {
    setupTabBarItems()
    
    let presentables = [
      walletCoordinator,
      activityCoordinator,
      browserCoordinator,
      settingsCoordinator
    ]
      .map {
        $0.start()
        return $0.router.rootViewController
      }
    router.set(presentables: presentables, options: .init(isAnimated: false))
  }
}

// MARK: - WalletCoordinatorOutput

extension TabBarCoordinator: WalletCoordinatorOutput {
  func walletCoordinatorOpenCreateImportWallet(_ coordinator: WalletCoordinator) {
    let module = SetupWalletAssembly.create(output: self)
    let modalCardContainerViewController = ModalCardContainerViewController(content: module.view)
    modalCardContainerViewController.headerSize = .small
    
    router.present(modalCardContainerViewController)
  }
}

// MARK: - SetupWalletModuleOutput

extension TabBarCoordinator: SetupWalletModuleOutput {
  
}

// MARK: - Private

private extension TabBarCoordinator {
  func setupTabBarItems() {
    let walletTabBarItem = UITabBarItem(title: "Wallet",
                                        image: .Icons.TabBar.wallet,
                                        tag: 0)
    walletCoordinator.router.rootViewController.tabBarItem = walletTabBarItem
    
    let activityTabBarItem = UITabBarItem(title: "Activity",
                                          image: .Icons.TabBar.activity,
                                          tag: 0)
    activityCoordinator.router.rootViewController.tabBarItem = activityTabBarItem
    
    let browserTabBarItem = UITabBarItem(title: "Browser",
                                         image: .Icons.TabBar.browser,
                                         tag: 0)
    browserCoordinator.router.rootViewController.tabBarItem = browserTabBarItem
    
    let settingsTabBarItem = UITabBarItem(title: "Settings",
                                         image: .Icons.TabBar.settings,
                                         tag: 0)
    settingsCoordinator.router.rootViewController.tabBarItem = settingsTabBarItem
  }
}
