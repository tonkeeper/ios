//
//  ImportWalletAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import Foundation

struct ImportWalletAssembly {
  
  let passcodeAssembly = PasscodeAssembly()
  
  func enterMnemonic(output: EnterMnemonicModuleOutput) -> Module<EnterMnemonicViewController, Void> {
    return EnterMnemonicAssembly.create(output: output)
  }
  
  func createPasscodeCoordinator(router: NavigationRouter) -> CreatePasscodeCoordinator {
    let coordinator = CreatePasscodeCoordinator(router: router, assembly: passcodeAssembly)
    return coordinator
  }
}
