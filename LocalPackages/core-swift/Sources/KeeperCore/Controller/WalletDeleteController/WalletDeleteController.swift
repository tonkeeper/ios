import Foundation

public final class WalletDeleteController {
  
  private let walletStore: WalletsStore
  private let keeperInfoStore: KeeperInfoStore
  private let mnemonicsRepository: MnemonicsRepository
  
  init(walletStore: WalletsStore,
       keeperInfoStore: KeeperInfoStore,
       mnemonicsRepository: MnemonicsRepository) {
    self.walletStore = walletStore
    self.keeperInfoStore = keeperInfoStore
    self.mnemonicsRepository = mnemonicsRepository
  }
  
  public func deleteWallet(wallet: Wallet, passcode: String) async {
    await walletStore.deleteWallet(wallet)
    try? await mnemonicsRepository.deleteMnemonic(wallet: wallet, password: passcode)
  }
  
  public func deleteWallet(wallet: Wallet) async {
    await walletStore.deleteWallet(wallet)
  }
  
  public func deleteAll() async {
    await walletStore.deleteAllWallets()
    if mnemonicsRepository.hasMnemonics() {
      try? await mnemonicsRepository.deleteAll()
    }
  }
}
