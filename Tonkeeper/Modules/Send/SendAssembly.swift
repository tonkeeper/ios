//
//  SendAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 31.5.23..
//

import UIKit
import WalletCoreKeeper
import TonSwift

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
  
  func sendCollectibleCoordinator(router: NavigationRouter,
                                  nftAddress: Address) -> SendCollectibleCoordinator {
    SendCollectibleCoordinator(
      router: router,
      nftAddress: nftAddress,
      walletCoreAssembly: walletCoreAssembly
    )
  }
}
