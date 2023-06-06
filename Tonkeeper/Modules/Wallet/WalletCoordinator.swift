//
//  WalletCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

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
    let module = walletAssembly.walletRootModule(output: self,
                                                 tokensListModuleOutput: self)
    router.setPresentables([(module.view, nil)])
  }
}

// MARK: - WalletRootModuleOutput

extension WalletCoordinator: WalletRootModuleOutput {
  func openQRScanner() {
    let module = walletAssembly.qrScannerModule(output: self)
    router.present(module.view)
  }
  
  func openSend() {
    let coordinator = walletAssembly.sendCoordinator(output: self)
    addChild(coordinator)
    coordinator.start()
    router.present(coordinator.router.rootViewController)
  }
  
  func openReceive() {
    let coordinator = walletAssembly.receieveCoordinator(output: self)
    addChild(coordinator)
    coordinator.start()
    router.present(coordinator.router.rootViewController, dismiss: { [weak self, weak coordinator] in
      self?.removeChild(coordinator!)
    })
  }
}

// MARK: - QRScannerModuleOutput

extension WalletCoordinator: QRScannerModuleOutput {
  func qrScannerModuleDidFinish() {
    router.dismiss()
  }
}

// MARK: - TokensListModuleOutput

extension WalletCoordinator: TokensListModuleOutput {
  
}

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
