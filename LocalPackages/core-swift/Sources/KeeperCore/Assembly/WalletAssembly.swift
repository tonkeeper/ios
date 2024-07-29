import Foundation

public final class WalletAssembly {
  
  private let servicesAssembly: ServicesAssembly
  private let storesAssembly: StoresAssembly
  private let walletUpdateAssembly: WalletsUpdateAssembly
  
  public let walletsStore: WalletsStore
  
  init(servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly,
       walletUpdateAssembly: WalletsUpdateAssembly,
       wallets: [Wallet],
       activeWallet: Wallet) {
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
    self.walletUpdateAssembly = walletUpdateAssembly

    self.walletsStore = WalletsStore(
      state: WalletsState(wallets: wallets, activeWallet: activeWallet),
      keeperInfoStore: storesAssembly.keeperInfoStore
    )
  }
}
