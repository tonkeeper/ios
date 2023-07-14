//
//  WalletTokenDetailsAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 13.7.23..
//

import Foundation
import WalletCore

final class WalletTokenDetailsAssembly {
  func coordinator(token: WalletBalanceModel.Token,
                   router: NavigationRouter) -> WalletTokenDetailsCoordinator {
    return WalletTokenDetailsCoordinator(token: token,
                                         router: router)
  }
}
