import Foundation
import CoreComponents
import TonSwift

public final class KeysAddController {
  private let walletKeysStore: WalletKeysStore
  private let mnemonicsRepositoty: MnemonicsRepository
  
  init(walletKeysStore: WalletKeysStore,
       mnemonicsRepositoty: MnemonicsRepository) {
    self.walletKeysStore = walletKeysStore
    self.mnemonicsRepositoty = mnemonicsRepositoty
  }
  
  func getWalletKeys() -> [WalletKey] {
    walletKeysStore.getWalletKeys()
  }
  
  public func createWalletKey(name: String, password: String) throws {
    let mnemonic = try Mnemonic(mnemonicWords: TonSwift.Mnemonic.mnemonicNew(wordsCount: 24))
    let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(
      mnemonicArray: mnemonic.mnemonicWords
    )
    let walletKey = WalletKey(name: name, publicKey: keyPair.publicKey)
    
    try mnemonicsRepositoty.saveMnemonic(
      mnemonic,
      walletKey: walletKey,
      password: password
    )
    try walletKeysStore.addWalletKey(walletKey)
  }
  
  public func importWalletKey(phrase: [String],
                              name: String,
                              password: String) throws {
    let mnemonic = try Mnemonic(mnemonicWords: phrase)
    let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(
      mnemonicArray: mnemonic.mnemonicWords
    )

    let walletKey = WalletKey(name: name, publicKey: keyPair.publicKey)

    try mnemonicsRepositoty.saveMnemonic(
      mnemonic,
      walletKey: walletKey,
      password: password
    )
    try walletKeysStore.addWalletKey(walletKey)
  }

}
