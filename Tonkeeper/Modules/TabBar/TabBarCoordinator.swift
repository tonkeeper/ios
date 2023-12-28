//
//  TabBarCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit
import WalletCoreKeeper

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
  
  private let authEventsDaemon: AuthEventsDaemon
  private var _tonConnectConfirmationCoordinator: TonConnectConfirmationCoordinator?
  
  private var transactionDidSendNotificationToken: AnyObject?
  
  init(router: TabBarRouter,
       assembly: TabBarAssembly) {
    self.assembly = assembly
    self.walletCoordinator = assembly.walletCoordinator()
    self.activityCoordinator = assembly.activityCoordinator()
    self.browserCoordinator = assembly.browserCoordinator()
    self.settingsCoordinator = assembly.settingsCoordinator()
    self.authEventsDaemon = assembly.authEventsDaemon
    super.init(router: router)
    self.settingsCoordinator.output = self
    subscribeOnNotification()
  }
  
  deinit {
    authEventsDaemon.removeObserver(self)
    authEventsDaemon.stop()
    if let transactionDidSendNotificationToken = transactionDidSendNotificationToken {
      NotificationCenter.default.removeObserver(transactionDidSendNotificationToken)
    }
  }
  
  override func start(deeplink: Deeplink?) {
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
    router.set(presentables: presentables, options: .init(isAnimated: false)) { [weak self] in
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        self?.handleDeeplink(deeplink)
      }
    }
    authEventsDaemon.addObserver(self)
    authEventsDaemon.start()
  }
  
  override func handleDeeplink(_ deeplink: Deeplink?) {
    switch deeplink {
    case let walletCoreDeeplink as WalletCoreKeeper.Deeplink:
      switch walletCoreDeeplink {
      case .tonConnect(let tonConnectDeeplink):
        openTonConnectDeeplink(tonConnectDeeplink)
      case .ton(let tonDeeplink):
        switch tonDeeplink {
        case .transfer(let address):
          self.openSend(recipient: Recipient(address: address, domain: nil))
        }
      }
    default: return
    }
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
    ToastController.hideAll()
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
          router.present(initialPresentable, dismiss: { [weak self, weak coordinator] in
            guard let coordinator = coordinator else { return }
            self?.removeChild(coordinator)
          })
        }
      } catch {
        await MainActor.run {
          ToastController.hideToast()
        }
      }
    }
  }
  
  func subscribeOnNotification() {
    transactionDidSendNotificationToken = NotificationCenter.default
      .addObserver(
        forName: Notification.Name(rawValue: "DidSendTransaction"), object: nil, queue: .main
      ) { [weak self] _ in
        self?.router.rootViewController.selectedIndex = 1
      }
  }
  
  func openSend(recipient: Recipient?) {
    let coordinator = assembly.walletAssembly.sendCoordinator(
      output: self,
      recipient: recipient
    )
    addChild(coordinator)
    coordinator.start()
    
    if let presentedViewController = router.rootViewController.presentedViewController {
      presentedViewController.present(coordinator.router.rootViewController, animated: true)
    } else {
      router.present(coordinator.router.rootViewController)
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
  
  func walletCoordinator(_ coordinator: WalletCoordinator, openSend recipient: Recipient?) {
    openSend(recipient: recipient)
  }
}

// MARK: - AuthEventsDaemonObserver

extension TabBarCoordinator: AuthEventsDaemonObserver {
  func authEventsDaemon(_ daemon: AuthEventsDaemon,
                        didReceiveTonConnectAppRequest appRequest: TonConnect.AppRequest,
                        app: TonConnectApp) {
    Task { @MainActor in
      let tonConnectConfirmationCoordinator: TonConnectConfirmationCoordinator
      if let _tonConnectConfirmationCoordinator = self._tonConnectConfirmationCoordinator {
        tonConnectConfirmationCoordinator = _tonConnectConfirmationCoordinator
      } else {
        tonConnectConfirmationCoordinator = assembly.tonConnectAssembly.confirmationCoordinator()
        tonConnectConfirmationCoordinator.output = self
        addChild(tonConnectConfirmationCoordinator)
        tonConnectConfirmationCoordinator.start()
        _tonConnectConfirmationCoordinator = tonConnectConfirmationCoordinator
      }
      
      tonConnectConfirmationCoordinator.handleAppRequest(
        appRequest,
        app: app
      )
    }
  }
}

// MARK: - TonConnectConfirmationCoordinatorOutput

extension TabBarCoordinator: TonConnectConfirmationCoordinatorOutput {
  func tonConnectConfirmationCoordinatorDidFinish(_ coordinator: TonConnectConfirmationCoordinator) {
    removeChild(coordinator)
  }
}

// MARK: - SendCoordinatorOutput

extension TabBarCoordinator: SendCoordinatorOutput {
  func sendCoordinatorDidClose(_ coordinator: SendCoordinator) {
    removeChild(coordinator)
  }
}

