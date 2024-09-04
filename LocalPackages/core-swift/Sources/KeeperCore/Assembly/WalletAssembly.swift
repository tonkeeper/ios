import Foundation

public final class WalletAssembly {
  
  private let servicesAssembly: ServicesAssembly
  private let storesAssembly: StoresAssembly
  private let walletUpdateAssembly: WalletsUpdateAssembly
  
  public let walletsStore: WalletsStore
  
  init(servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly,
       walletUpdateAssembly: WalletsUpdateAssembly) {
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
    self.walletUpdateAssembly = walletUpdateAssembly

    self.walletsStore = WalletsStore(
      state: WalletsState(
        wallets: [],
        activeWallet: Wallet(
          id: "",
          identity: WalletIdentity(network: .mainnet, kind: .Watchonly(.Domain("", .mock(workchain: 1, seed: "")))),
          metaData: WalletMetaData(label: "sd", tintColor: .Aquamarine, icon: .icon(.bankCard)),
          setupSettings: WalletSetupSettings(backupDate: nil)
        )
      ),
      keeperInfoStore: storesAssembly.keeperInfoStore
    )
  }
}
