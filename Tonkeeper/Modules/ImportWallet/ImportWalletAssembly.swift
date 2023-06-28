//
//  ImportWalletAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import Foundation

struct ImportWalletAssembly {
  
  func enterMnemonic(output: EnterMnemonicModuleOutput) -> Module<EnterMnemonicViewController, Void> {
    return EnterMnemonicAssembly.create(output: output)
  }
}
