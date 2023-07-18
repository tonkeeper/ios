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
  let sendAssembly: SendAssembly
  
  init(walletCoreAssembly: WalletCoreAssembly,
       sendAssembly: SendAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
    self.sendAssembly = sendAssembly
  }
    
  func coordinator(token: Token,
                   router: NavigationRouter) -> WalletTokenDetailsCoordinator {
    return WalletTokenDetailsCoordinator(token: token,
                                         walletCoreAssembly: walletCoreAssembly,
                                         sendAssembly: sendAssembly,
                                         router: router)
  }
}
