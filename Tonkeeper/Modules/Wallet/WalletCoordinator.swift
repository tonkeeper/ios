//
//  WalletCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit
import WalletCore

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
}

// MARK: - WalletRootModuleOutput

extension WalletCoordinator: WalletRootModuleOutput {
  func openQRScanner() {
    let module = walletAssembly.qrScannerModule(output: self)
    router.present(module.view)
  }
  
  func openSend(address: String?) {
    let coordinator = walletAssembly.sendCoordinator(
      output: self,
      address: address
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
      self?.removeChild(coordinator!)
    })
  }
  
  func openBuy() {
    let coordinator = walletAssembly.buyCoordinator()
    addChild(coordinator)
    coordinator.start()
    router.present(coordinator.router.rootViewController, dismiss: { [weak self, weak coordinator] in
      self?.removeChild(coordinator!)
    })
  }
  
  func didSelectToken(_ token: WalletBalanceModel.Token) {
    
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
          self?.openSend(address: address)
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

extension WalletCoordinator: ReceiveCoordinatorOutput {
  func receiveCoordinatorDidClose(_ coordinator: ReceiveCoordinator) {
    router.dismiss()
    removeChild(coordinator)
  }
}
