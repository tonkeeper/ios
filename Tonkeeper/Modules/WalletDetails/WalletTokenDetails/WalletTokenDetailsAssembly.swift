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
  let inAppBrowserAssembly: InAppBrowserAssembly
  
  init(walletCoreAssembly: WalletCoreAssembly,
       sendAssembly: SendAssembly,
       receiveAssembly: ReceiveAssembly,
       inAppBrowserAssembly: InAppBrowserAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
    self.sendAssembly = sendAssembly
    self.receiveAssembly = receiveAssembly
    self.inAppBrowserAssembly = inAppBrowserAssembly
  }
    
  func coordinator(token: Token,
                   router: NavigationRouter) -> WalletTokenDetailsCoordinator {
    return WalletTokenDetailsCoordinator(token: token,
                                         walletCoreAssembly: walletCoreAssembly,
                                         sendAssembly: sendAssembly,
                                         receiveAssembly: receiveAssembly,
                                         inAppBrowserAssembly: inAppBrowserAssembly,
                                         router: router)
  }
}
