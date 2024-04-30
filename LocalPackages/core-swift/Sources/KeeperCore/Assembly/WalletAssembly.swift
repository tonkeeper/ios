import Foundation

public final class WalletAssembly {
  
  private let servicesAssembly: ServicesAssembly
  private let storesAssembly: StoresAssembly
  private let walletUpdateAssembly: WalletsUpdateAssembly
  
  public let walletStore: WalletsStore
  
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
  }
}
