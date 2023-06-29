//
//  EnterMnemonicEnterMnemonicProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 28/06/2023.
//

import Foundation

protocol EnterMnemonicModuleOutput: AnyObject {
  func didInputMnemonic()
}

protocol EnterMnemonicModuleInput: AnyObject {}

protocol EnterMnemonicPresenterInput {
  func viewDidLoad()
  func validate(word: String) -> Bool
  func didEnterMnemonic(_ mnemonic: [String])
}

protocol EnterMnemonicViewInput: AnyObject {
  func update(with model: EnterMnemonicView.Model)
  func showMnemonicValidationError()
}
