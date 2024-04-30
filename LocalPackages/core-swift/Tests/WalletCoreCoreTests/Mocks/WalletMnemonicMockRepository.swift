//
//  WalletMnemonicMockRepository.swift
//
//
//  Created by Grigory Serebryanyy on 18.11.2023.
//

import Foundation
@testable import WalletCoreCore

final class WalletMnemonicMockRepository: WalletMnemonicRepository {
    
    enum Error: Swift.Error {
        case noMnemonic
    }
    
    var mnemonics = [WalletID: Mnemonic]()
    
    func getMnemonic(wallet: Wallet) throws -> Mnemonic {
        guard let mnemonic = mnemonics[try wallet.identity.id()] else {
            throw Error.noMnemonic
        }
        return mnemonic
    }
    
    func saveMnemonic(_ mnemonic: Mnemonic, for wallet: Wallet) throws {
        mnemonics[try wallet.identity.id()] = mnemonic
    }
    
    func reset() {
        mnemonics = [:]
    }
}
