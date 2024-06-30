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
  
  private weak var _balanceStore: BalanceStoreV2?
  public var balanceStore: BalanceStoreV2 {
    if let _balanceStore {
      return _balanceStore
    }
    let store = BalanceStoreV2(walletsStore: walletsAssembly.walletsStoreV2,
                               repository: repositoriesAssembly.walletBalanceRepositoryV2()
    )
    _balanceStore = store
    return store
  }
  
  private weak var _convertedBalanceStore: ConvertedBalanceStoreV2?
  public var convertedBalanceStore: ConvertedBalanceStoreV2 {
    if let _convertedBalanceStore {
      return _convertedBalanceStore
    }
    let store = ConvertedBalanceStoreV2(
      balanceStore: balanceStore,
      tonRatesStore: storesAssembly.tonRatesStoreV2,
      currencyStore: storesAssembly.currencyStoreV2
    )
    _convertedBalanceStore = store
    return store
  }
  
  private weak var _walletsTotalBalanceStore: TotalBalanceStoreV2?
  public var walletsTotalBalanceStore: TotalBalanceStoreV2 {
    if let _walletsTotalBalanceStore {
      return _walletsTotalBalanceStore
    }
    let store = TotalBalanceStoreV2(convertedBalanceStore: convertedBalanceStore)
    _walletsTotalBalanceStore = store
    return store
  }
}
