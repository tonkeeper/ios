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
    let module = walletAssembly.walletRootModule(output: self)
    router.setPresentables([(module.view, nil)])
  }
}

extension WalletCoordinator: WalletRootModuleOutput {}
