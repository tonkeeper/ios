import Foundation

public final class WalletDeleteController {
  
  private let walletsStoreUpdater: WalletsStoreUpdater
  private let mnemonicsRepository: MnemonicsRepository
  
  init(walletsStoreUpdater: WalletsStoreUpdater,
       mnemonicsRepository: MnemonicsRepository) {
    self.walletsStoreUpdater = walletsStoreUpdater
    self.mnemonicsRepository = mnemonicsRepository
  }
  
  public func deleteWallet(wallet: Wallet, passcode: String) async {
    await walletsStoreUpdater.deleteWallet(wallet)
    try? await mnemonicsRepository.deleteMnemonic(wallet: wallet, password: passcode)
  }
  
  public func deleteWallet(wallet: Wallet) async {
    await walletsStoreUpdater.deleteWallet(wallet)
  }
  
  public func deleteAll() async {
    await walletsStoreUpdater.deleteAllWallets()
    if mnemonicsRepository.hasMnemonics() {
      try? await mnemonicsRepository.deleteAll()
    }
  }
}
