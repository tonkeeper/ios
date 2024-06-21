import Foundation

public final class WalletAssembly {
  
  private let servicesAssembly: ServicesAssembly
  private let storesAssembly: StoresAssembly
  private let walletUpdateAssembly: WalletsUpdateAssembly
  
  public let walletStore: WalletsStore
  public let walletsStoreV2: WalletsStoreV2
  
  init(servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly,
       walletUpdateAssembly: WalletsUpdateAssembly,
       wallets: [Wallet],
       activeWallet: Wallet) {
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
    self.walletUpdateAssembly = walletUpdateAssembly
    
    self.walletStore = WalletsStore(
      wallets: wallets,
      activeWallet: activeWallet,
      walletsService: servicesAssembly.walletsService(),
      backupStore: storesAssembly.backupStore,
      walletsStoreUpdate: walletUpdateAssembly.walletsStoreUpdate
    )
    
    self.walletsStoreV2 = WalletsStoreV2(
      state: WalletsState(wallets: wallets, activeWallet: activeWallet),
      keeperInfoStore: storesAssembly.keeperInfoStore
    )
  }
}
