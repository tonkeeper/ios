//
//  SettingsAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import Foundation
import WalletCore

final class SettingsAssembly {
  private let walletCoreAssembly: WalletCoreAssembly
  
  init(walletCoreAssembly: WalletCoreAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
  }
  
  func coordinator(router: NavigationRouter) -> SettingsCoordinator {
    SettingsCoordinator(router: router,
                        walletCoreAssembly: walletCoreAssembly)
  }
}
