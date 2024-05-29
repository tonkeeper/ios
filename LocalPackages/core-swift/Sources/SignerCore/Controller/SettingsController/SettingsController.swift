import Foundation
import CoreComponents
import TonSwift

public final class SettingsController {
  private let walletKeysStore: WalletKeysStore
  
  init(walletKeysStore: WalletKeysStore) {
    self.walletKeysStore = walletKeysStore
  }
  
  public func deleteKey(_ key: WalletKey) throws {
    try walletKeysStore.deleteKey(key)
  }
}
