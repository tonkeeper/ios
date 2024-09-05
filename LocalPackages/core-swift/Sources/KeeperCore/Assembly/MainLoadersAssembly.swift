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
  
//  private weak var _walletStateLoader: WalletStateLoader?
//  var walletStateLoader: WalletStateLoader {
//    if let _walletStateLoader {
//      return _walletStateLoader
//    }
//    let loader = WalletStateLoader(
//      balanceStore: storesAssembly.balanceStore,
//      currencyStore: storesAssembly.currencyStoreV3,
//      walletsStore: storesAssembly.walletsStore,
//      ratesStore: storesAssembly.tonRatesStoreV3,
//      stakingPoolsStore: storesAssembly.stackingPoolsStoreV3,
//      balanceService: servicesAssembly.balanceService(),
//      stackingService: servicesAssembly.stackingService(),
//      accountNFTService: servicesAssembly.accountNftService(),
//      ratesService: servicesAssembly.ratesService(),
//      backgroundUpdateUpdater: storesAssembly.backgroundUpdateUpdater
//    )
//    _walletStateLoader = loader
//    return loader
//  }
  
  private weak var _accountNftsLoader: AccountNftsLoader?
  public var accountNftsLoader: AccountNftsLoader {
    if let _accountNftsLoader {
      return _accountNftsLoader
    }
    let loader = AccountNftsLoader(
      accountNFTsStore: mainStoresAssembly.accountNftsStore,
      nftsService: servicesAssembly.accountNftService()
    )
    _accountNftsLoader = loader
    return loader
  }
}
