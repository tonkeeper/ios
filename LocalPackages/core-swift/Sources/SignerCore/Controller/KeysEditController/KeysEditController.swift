import Foundation
import CoreComponents
import TonSwift

public final class KeysEditController {
  private let walletKeysStore: WalletKeysStore
  private let mnemonicRepositoty: WalletKeyMnemonicRepository
  
  init(walletKeysStore: WalletKeysStore,
       mnemonicRepositoty: WalletKeyMnemonicRepository) {
    self.walletKeysStore = walletKeysStore
    self.mnemonicRepositoty = mnemonicRepositoty
  }
  
  public func updateWalletKeyName(walletKey: WalletKey, 
                                  name: String) throws {
    try walletKeysStore.updateWalletKeyName(walletKey, name: name)
  }
}
