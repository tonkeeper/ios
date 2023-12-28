//
//  WalletCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit
import WalletCoreKeeper
import TonSwift
 
protocol WalletCoordinatorOutput: AnyObject {
  func walletCoordinator(_ coordinator: WalletCoordinator,
                         openTonConnectDeeplink deeplink: TonConnectDeeplink)
  func walletCoordinator(_ coordinator: WalletCoordinator,
                         openSend recipient: Recipient?)
}

final class WalletCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: WalletCoordinatorOutput?
  
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
    let module = walletAssembly.walletRootModule(
      output: self,
      transactionsEventDaemon: walletAssembly.walletCoreAssembly.transactionsEventsDaemon()
    )
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
  
  func openCollectibleDetails(collectible: WalletCollectibleItemViewModel) {
    let navigationController = UINavigationController()
    navigationController.configureDefaultAppearance()
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = walletAssembly
      .collectibleAssembly
      .coordinator(router: router,
                   collectibleAddress: collectible.address)
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
    output?.walletCoordinator(self, openSend: recipient)
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
    openCollectibleDetails(collectible: collectibleItem)
  }
}

// MARK: - QRScannerModuleOutput

extension WalletCoordinator: QRScannerModuleOutput {
  func qrScannerModuleDidFinish() {
    router.dismiss()
  }
  
  func isQrCodeValid(string: String) -> Bool {
    (try? walletAssembly.deeplinkParser.isValid(string: string)) ?? false
  }
  
  func didScanQrCode(with string: String) {
    router.dismiss()
    do {
      switch try walletAssembly.deeplinkParser.parse(string: string) {
      case .ton(let tonDeeplink):
        switch tonDeeplink {
        case .transfer(let address):
          router.dismiss { [weak self] in
            self?.openSend(recipient: Recipient(address: address, domain: nil))
          }
        }
      case .tonConnect(let tonConnectDeeplink):
        output?.walletCoordinator(
          self,
          openTonConnectDeeplink: tonConnectDeeplink
        )
      }
    } catch {}
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
