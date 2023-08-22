//
//  WalletCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit
import WalletCore
import TonSwift

final class WalletCoordinator: Coordinator<NavigationRouter> {
  
  private let walletAssembly: WalletAssembly
  
  init(router: NavigationRouter,
       walletAssembly: WalletAssembly) {
    self.walletAssembly = walletAssembly
    super.init(router: router)
  }
  
  override func start() {
    openWalletRoot()
  }
}

private extension WalletCoordinator {
  func openWalletRoot() {
    let module = walletAssembly.walletRootModule(output: self)
    router.setPresentables([(module.view, nil)])
  }
  
  func openTokenDetails(token: Token) {
    let coordinator = walletAssembly
      .walletTokenDetailsAssembly
      .coordinator(token: token, router: router)
    addChild(coordinator)
    coordinator.start()
    
    guard let initialPresentable = coordinator.initialPresentable else { return }
    router.push(presentable: initialPresentable, dismiss: { [weak self, weak coordinator] in
      guard let self = self, let coordinator = coordinator else { return }
      self.removeChild(coordinator)
    })
  }
  
  func openOldWalletMigration() {
    
  }
  
  func openCollectibleDetails() {
    let navigationController = UINavigationController()
    navigationController.configureDefaultAppearance()
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = walletAssembly
      .collectibleAssembly
      .coordinator(router: router)
    coordinator.output = self
    
    addChild(coordinator)
    coordinator.start()
    self.router.present(coordinator.router.rootViewController, dismiss: { [weak self, weak coordinator] in
      guard let self = self, let coordinator = coordinator else { return }
      self.removeChild(coordinator)
    })
  }
}

// MARK: - WalletRootModuleOutput

extension WalletCoordinator: WalletRootModuleOutput {
  func openQRScanner() {
    let module = walletAssembly.qrScannerModule(output: self)
    router.present(module.view)
  }
  
  func openSend(recipient: Recipient?) {
    let coordinator = walletAssembly.sendCoordinator(
      output: self,
      recipient: recipient
    )
    addChild(coordinator)
    coordinator.start()
    router.present(coordinator.router.rootViewController)
  }
  
  func openReceive(address: String) {
    let coordinator = walletAssembly.receieveCoordinator(output: self, address: address)
    addChild(coordinator)
    coordinator.start()
    router.present(coordinator.router.rootViewController, dismiss: { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    })
  }
  
  func openBuy() {
    let coordinator = walletAssembly.buyCoordinator()
    addChild(coordinator)
    coordinator.start()
    router.present(coordinator.router.rootViewController, dismiss: { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    })
  }
  
  func didSelectItem(_ item: WalletItemViewModel) {
    switch item.type {
    case .old:
      openOldWalletMigration()
    case .token(let tokenInfo):
      openTokenDetails(token: .token(tokenInfo))
    case .ton:
      openTokenDetails(token: .ton)
    }
  }
  
  func didSelectCollectibleItem(_ collectibleItem: WalletCollectibleItemViewModel) {
    openCollectibleDetails()
  }
}

// MARK: - QRScannerModuleOutput

extension WalletCoordinator: QRScannerModuleOutput {
  func qrScannerModuleDidFinish() {
    router.dismiss()
  }
  
  func didScanQrCode(with string: String) {
    let deeplinkParser = walletAssembly.deeplinkParser
    guard let deeplink = try? deeplinkParser.parse(string: string) else { return }
    
    switch deeplink {
    case let .ton(tonDeeplink):
      switch tonDeeplink {
      case let .transfer(address):
        router.dismiss { [weak self] in
          self?.openSend(recipient: Recipient(address: address, domain: nil))
        }
      }
    }
  }
}

// MARK: - SendCoordinatorOutput

extension WalletCoordinator: SendCoordinatorOutput {
  func sendCoordinatorDidClose(_ coordinator: SendCoordinator) {
    router.dismiss()
    removeChild(coordinator)
  }
}

// MARK: - ReceiveCoordinatorOutput

extension WalletCoordinator: ReceiveCoordinatorOutput {
  func receiveCoordinatorDidClose(_ coordinator: ReceiveCoordinator) {
    router.dismiss()
    removeChild(coordinator)
  }
}

// MARK: -

extension WalletCoordinator: CollectibleCoordinatorOutput {
  func collectibleCoordinatorDidFinish(_ coordinator: CollectibleCoordinator) {
    router.dismiss()
    removeChild(coordinator)
  }
}
