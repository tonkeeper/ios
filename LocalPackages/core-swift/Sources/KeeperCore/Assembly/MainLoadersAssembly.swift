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
  
  private weak var _walletStateLoader: WalletStateLoader?
  var walletStateLoader: WalletStateLoader {
    if let _walletStateLoader {
      return _walletStateLoader
    }
    let loader = WalletStateLoader(
      balanceStore: mainStoresAssembly.balanceStore,
      currencyStore: storesAssembly.currencyStoreV2,
      walletsStore: walletAssembly.walletsStoreV2,
      ratesStore: storesAssembly.tonRatesStoreV2,
      stakingPoolsStore: storesAssembly.stackingPoolsStore,
      balanceService: servicesAssembly.balanceService(),
      stackingService: servicesAssembly.stackingService(),
      ratesService: servicesAssembly.ratesService(),
      backgroundUpdateUpdater: mainStoresAssembly.backgroundUpdateUpdater
    )
    _walletStateLoader = loader
    return loader
  }
}
