//
//  CollectibleAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 21.8.23..
//

import Foundation
import TonSwift

struct CollectibleAssembly {
  let walletCoreAssembly: WalletCoreAssembly
  let sendAssembly: SendAssembly
  
  init(walletCoreAssembly: WalletCoreAssembly,
       sendAssembly: SendAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
    self.sendAssembly = sendAssembly
  }
  
  func coordinator(router: NavigationRouter,
                   collectibleAddress: Address) -> CollectibleCoordinator {
    return CollectibleCoordinator(router: router,
                                  collectibleAddress: collectibleAddress,
                                  walletCoreAssembly: walletCoreAssembly,
                                  sendAssembly: sendAssembly)
  }
}
