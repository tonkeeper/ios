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
  
  init(walletCoreAssembly: WalletCoreAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
  }
  
  func coordinator(router: NavigationRouter,
                   collectibleAddress: Address) -> CollectibleCoordinator {
    return CollectibleCoordinator(router: router,
                                  collectibleAddress: collectibleAddress,
                                  walletCoreAssembly: walletCoreAssembly)
  }
}
