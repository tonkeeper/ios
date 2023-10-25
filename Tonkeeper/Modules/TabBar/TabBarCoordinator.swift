//
//  TabBarCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit
import WalletCore

protocol TabBarCoordinatorOutput: AnyObject {
  func tabBarCoordinatorDidLogout(_ coordinator: TabBarCoordinator)
}

final class TabBarCoordinator: Coordinator<TabBarRouter> {
  
  weak var output: TabBarCoordinatorOutput?
  
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
    self.settingsCoordinator.output = self
  }
  
  override func start() {
    setupTabBarItems()
    
    let presentables = [
      walletCoordinator,
      activityCoordinator,
      settingsCoordinator
    ]
      .map {
        $0.start()
        return $0.router.rootViewController
      }
    router.set(presentables: presentables, options: .init(isAnimated: false))
  }
}

// MARK: - Private

private extension TabBarCoordinator {
  func setupTabBarItems() {
    let walletTabBarItem = UITabBarItem(title: "Wallet",
                                        image: .Icons.TabBar.wallet,
                                        tag: 0)
    walletCoordinator.router.rootViewController.tabBarItem = walletTabBarItem
    walletCoordinator.output = self
    
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
  
  func openTonConnectDeeplink(_ deeplink: TonConnectDeeplink) {
    ToastController.showToast(configuration: .loading)
    Task {
      do {
        let (parameters, manifest) = try await assembly
          .walletCoreAssembly
          .tonConnectDeeplinkProcessor()
          .processDeeplink(deeplink)
        await MainActor.run {
          ToastController.hideToast()
          let coordinator = assembly.tonConnectCoordinator(
            navigationRouter: Router(rootViewController: router.rootViewController),
            parameters: parameters,
            manifest: manifest
          )
          addChild(coordinator)
          coordinator.start()
          guard let initialPresentable = coordinator.initialPresentable else { return }
          router.present(initialPresentable, dismiss: { [weak self, coordinator] in
            self?.removeChild(coordinator)
          })
        }
      } catch {
        await MainActor.run {
          ToastController.showToast(configuration: .failed)
        }
      }
    }
  }
}

// MARK: - SettingsCoordinatorOutput

extension TabBarCoordinator: SettingsCoordinatorOutput {
  func settingsCoordinatorDidLogout(_ settingsCoordinator: SettingsCoordinator) {
    output?.tabBarCoordinatorDidLogout(self)
  }
}

// MARK: - WalletCoordinatorOutput

extension TabBarCoordinator: WalletCoordinatorOutput {
  func walletCoordinator(_ coordinator: WalletCoordinator,
                         openTonConnectDeeplink deeplink: TonConnectDeeplink) {
    self.openTonConnectDeeplink(deeplink)
  }
}
