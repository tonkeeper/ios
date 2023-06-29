//
//  MnemonicValidator.swift
//  Tonkeeper
//
//  Created by Grigory on 29.6.23..
//

import Foundation
import TonSwift

struct MnemonicValidator {
  func validate(word: String) -> Bool {
    return Mnemonic.words.contains(word)
  }
  
  func validate(mnemonic: [String]) -> Bool {
    return Mnemonic.mnemonicValidate(mnemonicArray: mnemonic)
  }
}
