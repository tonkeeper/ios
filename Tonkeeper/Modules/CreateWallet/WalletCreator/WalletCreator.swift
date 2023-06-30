//
//  WalletCreator.swift
//  Tonkeeper
//
//  Created by Grigory on 30.6.23..
//

import Foundation
import TonSwift

protocol WalletCreator {
  func createWallet() -> [String]
}

struct WalletCreatorImplementation: WalletCreator {
  func createWallet() -> [String] {
    Mnemonic.mnemonicNew(wordsCount: .mnemonicWordsCount)
  }
}

private extension Int {
  static let mnemonicWordsCount: Int = 24
}
