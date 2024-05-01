import Foundation
import CoreComponents
import TonSwift

public final class KeysAddController {
  private let walletKeysStore: WalletKeysStore
  private let mnemonicRepositoty: WalletKeyMnemonicRepository
  
  init(walletKeysStore: WalletKeysStore,
       mnemonicRepositoty: WalletKeyMnemonicRepository) {
    self.walletKeysStore = walletKeysStore
    self.mnemonicRepositoty = mnemonicRepositoty
  }
  
  func getWalletKeys() -> [WalletKey] {
    walletKeysStore.getWalletKeys()
  }
  
  public func createWalletKey(name: String) throws {
    let mnemonic = try Mnemonic(mnemonicWords: TonSwift.Mnemonic.mnemonicNew(wordsCount: 24))
    let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(
      mnemonicArray: mnemonic.mnemonicWords
    )
    let walletKey = WalletKey(name: name, publicKey: keyPair.publicKey)
    
    try mnemonicRepositoty.saveMnemonic(mnemonic, forWalletKey: walletKey)
    try walletKeysStore.addWalletKey(walletKey)
  }
  
  public func importWalletKey(phrase: [String],
                              name: String) throws {
    let mnemonic = try Mnemonic(mnemonicWords: phrase)
    let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(
      mnemonicArray: mnemonic.mnemonicWords
    )

    let walletKey = WalletKey(name: name, publicKey: keyPair.publicKey)

    try mnemonicRepositoty.saveMnemonic(mnemonic, forWalletKey: walletKey)
    try walletKeysStore.addWalletKey(walletKey)
  }

}
