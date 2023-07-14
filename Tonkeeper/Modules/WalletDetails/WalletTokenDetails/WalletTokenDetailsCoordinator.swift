//
//  WalletTokenDetailsCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 13.7.23..
//

import UIKit
import WalletCore

final class WalletTokenDetailsCoordinator: Coordinator<NavigationRouter> {
  let token: WalletBalanceModel.Token
  
  init(token: WalletBalanceModel.Token,
       router: NavigationRouter) {
    self.token = token
    super.init(router: router)
  }
  
  override func start() {
    openTokenDetails()
  }
}

private extension WalletTokenDetailsCoordinator {
  func openTokenDetails() {
    let module = TokenDetailsAssembly.module(output: self)
    module.view.setupBackButton()
    initialPresentable = module.view
  }
}

// MARK: - TokenDetailsModuleOutput

extension WalletTokenDetailsCoordinator: TokenDetailsModuleOutput {
  
}
