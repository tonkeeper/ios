import Foundation
import TonSwift

public final class MainStoresAssembly {
  
  private let walletsAssembly: WalletAssembly
  private let repositoriesAssembly: RepositoriesAssembly
  private let servicesAssembly: ServicesAssembly
  private let storesAssembly: StoresAssembly
  
  init(walletsAssembly: WalletAssembly,
       repositoriesAssembly: RepositoriesAssembly,
       servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly) {
    self.walletsAssembly = walletsAssembly
    self.repositoriesAssembly = repositoriesAssembly
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
  }
  
  private weak var _walletsBalanceStore: WalletsBalanceStoreV2?
  public var walletsBalanceStore: WalletsBalanceStoreV2 {
    if let _walletsBalanceStore {
      return _walletsBalanceStore
    }
    let store = WalletsBalanceStoreV2(walletsStore: walletsAssembly.walletsStoreV2,
                                      repository: repositoriesAssembly.walletBalanceRepositoryV2()
    )
    _walletsBalanceStore = store
    return store
  }
  
  private weak var _walletsTotalBalanceStore: WalletsTotalBalanceStoreV2?
  public var walletsTotalBalanceStore: WalletsTotalBalanceStoreV2 {
    if let _walletsTotalBalanceStore {
      return _walletsTotalBalanceStore
    }
    let store = WalletsTotalBalanceStoreV2(
      walletsStore: walletsAssembly.walletsStoreV2,
      balanceStore: walletsBalanceStore,
      tonRatesStore: storesAssembly.tonRatesStoreV2,
      currencyStore: storesAssembly.currencyStoreV2,
      totalBalanceService: servicesAssembly.totalBalanceService()
    )
    _walletsTotalBalanceStore = store
    return store
  }
}
