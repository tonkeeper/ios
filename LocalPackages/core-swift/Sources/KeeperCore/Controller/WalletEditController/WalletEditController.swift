import Foundation
import CoreComponents
import TonSwift

public final class WalletEditController {

  private let walletsStoreUpdate: WalletsStoreUpdate
  
  init(walletsStoreUpdate: WalletsStoreUpdate) {
    self.walletsStoreUpdate = walletsStoreUpdate
  }
  
  public func updateWallet(wallet: Wallet, metaData: WalletMetaData) throws {
    try walletsStoreUpdate.updateWallet(wallet, metaData: metaData)
  }
}
