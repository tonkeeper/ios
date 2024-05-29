import Foundation
import CoreComponents
import TonSwift

public final class KeysEditController {
  private let walletKeysStore: WalletKeysStore
  private let mnemonicsRepositoty: MnemonicsRepository
  
  init(walletKeysStore: WalletKeysStore,
       mnemonicsRepositoty: MnemonicsRepository) {
    self.walletKeysStore = walletKeysStore
    self.mnemonicsRepositoty = mnemonicsRepositoty
  }
  
  public func updateWalletKeyName(walletKey: WalletKey, 
                                  name: String) throws {
    try walletKeysStore.updateWalletKeyName(walletKey, name: name)
  }
}
