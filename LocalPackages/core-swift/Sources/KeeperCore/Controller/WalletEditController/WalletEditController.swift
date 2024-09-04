import Foundation
import CoreComponents
import TonSwift

public final class WalletEditController {

  private let walletsStore: WalletsStoreV3
  
  init(walletsStore: WalletsStoreV3) {
    self.walletsStore = walletsStore
  }
  
  public func updateWallet(wallet: Wallet, metaData: WalletMetaData) async {
    await walletsStore.setWallet(wallet, metaData: metaData)
  }
}
