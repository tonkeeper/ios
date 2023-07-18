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
  let receiveAssembly: ReceiveAssembly
  
  init(walletCoreAssembly: WalletCoreAssembly,
       sendAssembly: SendAssembly,
       receiveAssembly: ReceiveAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
    self.sendAssembly = sendAssembly
    self.receiveAssembly = receiveAssembly
  }
    
  func coordinator(token: Token,
                   router: NavigationRouter) -> WalletTokenDetailsCoordinator {
    return WalletTokenDetailsCoordinator(token: token,
                                         walletCoreAssembly: walletCoreAssembly,
                                         sendAssembly: sendAssembly,
                                         receiveAssembly: receiveAssembly,
                                         router: router)
  }
}
