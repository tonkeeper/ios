//
//  ActivityAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

struct ActivityAssembly {
  private let receiveAssembly: ReceiveAssembly
  private let collectibleAssembly: CollectibleAssembly
  private let walletCoreAssembly: WalletCoreAssembly
  
  init(receiveAssembly: ReceiveAssembly,
       collectibleAssembly: CollectibleAssembly,
       walletCoreAssembly: WalletCoreAssembly) {
    self.receiveAssembly = receiveAssembly
    self.collectibleAssembly = collectibleAssembly
    self.walletCoreAssembly = walletCoreAssembly
  }
 
  func coordinator(router: NavigationRouter) -> ActivityCoordinator {
    ActivityCoordinator(
      router: router,
      recieveAssembly: receiveAssembly,
      collectibleAssembly: collectibleAssembly,
      walletCoreAssembly: walletCoreAssembly)
  }
}
