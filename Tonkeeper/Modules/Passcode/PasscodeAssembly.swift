//
//  PasscodeAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 29.6.23..
//

import Foundation

final class PasscodeAssembly {
  
  let walletCoreAssembly: WalletCoreAssembly
  
  init(walletCoreAssembly: WalletCoreAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
  }
  
  func passcodeInputAssembly(
    output: PasscodeInputModuleOutput,
    configurator: PasscodeInputPresenterConfigurator
  ) -> Module<PasscodeInputViewController, Void> {
    return PasscodeInputAssembly.create(
      output: output,
      configurator: configurator
    )
  }
  
  func passcodeAuthConfigurator() -> PasscodeAuthConfigurator {
    PasscodeAuthConfigurator(passcodeController: walletCoreAssembly.passcodeController)
  }
}
