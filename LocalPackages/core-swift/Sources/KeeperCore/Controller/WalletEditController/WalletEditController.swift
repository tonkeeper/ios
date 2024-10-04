import Foundation
import CoreComponents
import TonSwift

public final class WalletEditController {

  private let walletsStore: WalletsStore
  
  init(walletsStore: WalletsStore) {
    self.walletsStore = walletsStore
  }
  
  public func updateWallet(wallet: Wallet, metaData: WalletMetaData) async {
    await walletsStore.setWallet(wallet, metaData: metaData)
  }
}
