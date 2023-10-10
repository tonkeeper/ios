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
  private let passcodeAssembly: PasscodeAssembly
  
  init(walletCoreAssembly: WalletCoreAssembly,
       passcodeAssembly: PasscodeAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
    self.passcodeAssembly = passcodeAssembly
  }
  
  func coordinator(router: NavigationRouter) -> SettingsCoordinator {
    SettingsCoordinator(router: router,
                        walletCoreAssembly: walletCoreAssembly,
                        passcodeAssembly: passcodeAssembly)
  }
}
