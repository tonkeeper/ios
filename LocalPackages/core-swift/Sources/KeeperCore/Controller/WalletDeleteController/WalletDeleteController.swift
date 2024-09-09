import Foundation

public final class WalletDeleteController {
  
  private let walletStore: WalletsStore
  private let keeperInfoStore: KeeperInfoStoreV3
  private let mnemonicsRepository: MnemonicsRepository
  
  init(walletStore: WalletsStore,
       keeperInfoStore: KeeperInfoStoreV3,
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
    await keeperInfoStore.updateKeeperInfo { _ in
      return nil
    }
    await walletStore.deleteAllWallets()
    if mnemonicsRepository.hasMnemonics() {
      try? await mnemonicsRepository.deleteAll()
    }
  }
}
