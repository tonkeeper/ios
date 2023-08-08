//
//  ActivityAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

struct ActivityAssembly {
  private let receiveAssembly: ReceiveAssembly
  private let walletCoreAssembly: WalletCoreAssembly
  
  init(receiveAssembly: ReceiveAssembly,
       walletCoreAssembly: WalletCoreAssembly) {
    self.receiveAssembly = receiveAssembly
    self.walletCoreAssembly = walletCoreAssembly
  }
 
  func coordinator(router: NavigationRouter) -> ActivityCoordinator {
    ActivityCoordinator(router: router, recieveAssembly: receiveAssembly, walletCoreAssembly: walletCoreAssembly)
  }
}
