import Foundation
import TonSwift

public final class MainLoadersAssembly {
  
  private let servicesAssembly: ServicesAssembly
  private let storesAssembly: StoresAssembly
  private let mainStoresAssembly: MainStoresAssembly
  private let walletAssembly: WalletAssembly
  
  init(servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly,
       mainStoresAssembly: MainStoresAssembly,
       walletAssembly: WalletAssembly) {
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
    self.mainStoresAssembly = mainStoresAssembly
    self.walletAssembly = walletAssembly
  }
  
  private weak var _walletBalanceLoaderV2: WalletBalanceLoaderV2?
  var walletBalanceLoaderV2: WalletBalanceLoaderV2 {
    if let _walletBalanceLoaderV2 {
      return _walletBalanceLoaderV2
    }
    let loader = WalletBalanceLoaderV2(
      balanceStore: mainStoresAssembly.walletsBalanceStore,
      currencyStore: storesAssembly.currencyStoreV2,
      walletsStore: walletAssembly.walletsStoreV2,
      balanceService: servicesAssembly.balanceService()
    )
    _walletBalanceLoaderV2 = loader
    return loader
  }
}
