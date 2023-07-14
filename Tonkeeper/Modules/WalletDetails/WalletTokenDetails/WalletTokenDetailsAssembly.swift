//
//  WalletTokenDetailsAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 13.7.23..
//

import Foundation
import WalletCore

final class WalletTokenDetailsAssembly {
  let walletCoreAssembly: WalletCoreAssembly
  
  init(walletCoreAssembly: WalletCoreAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
  }
  
  func coordinator(token: Token,
                   router: NavigationRouter) -> WalletTokenDetailsCoordinator {
    return WalletTokenDetailsCoordinator(token: token,
                                         walletCoreAssembly: walletCoreAssembly,
                                         router: router)
  }
}
