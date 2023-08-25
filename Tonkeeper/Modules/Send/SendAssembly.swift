//
//  SendAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 31.5.23..
//

import UIKit
import WalletCore

final class SendAssembly {
  let walletCoreAssembly: WalletCoreAssembly
  
  init(walletCoreAssembly: WalletCoreAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
  }
  
  func coordinator(router: NavigationRouter,
                   token: Token,
                   recipient: Recipient?) -> SendCoordinator {
    SendCoordinator(router: router,
                    walletCoreAssembly: walletCoreAssembly,
                    token: token,
                    recipient: recipient)
  }
  
  func sendCollectibleCoordinator(router: NavigationRouter) -> SendCollectibleCoordinator {
    SendCollectibleCoordinator(
      router: router,
      walletCoreAssembly: walletCoreAssembly
    )
  }
}
