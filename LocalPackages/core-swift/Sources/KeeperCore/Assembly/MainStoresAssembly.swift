import Foundation
import TonSwift

public final class MainStoresAssembly {
  
  private let walletsAssembly: WalletAssembly
  private let repositoriesAssembly: RepositoriesAssembly
  private let servicesAssembly: ServicesAssembly
  private let storesAssembly: StoresAssembly
  private let apiAssembly: APIAssembly
  
  init(walletsAssembly: WalletAssembly,
       repositoriesAssembly: RepositoriesAssembly,
       servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly,
       apiAssembly: APIAssembly) {
    self.walletsAssembly = walletsAssembly
    self.repositoriesAssembly = repositoriesAssembly
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
    self.apiAssembly = apiAssembly
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
  
  private weak var _processedBalanceStore: ProcessedBalanceStore?
  public var processedBalanceStore: ProcessedBalanceStore {
    if let _processedBalanceStore {
      return _processedBalanceStore
    }
    let store = ProcessedBalanceStore(
      walletsStore: walletsAssembly.walletsStoreV2,
      balanceStore: balanceStore,
      tonRatesStore: storesAssembly.tonRatesStoreV2,
      currencyStore: storesAssembly.currencyStoreV2,
      stakingPoolsStore: storesAssembly.stackingPoolsStore
    )
    _processedBalanceStore = store
    return store
  }
  
  private weak var _walletsTotalBalanceStore: TotalBalanceStoreV2?
  public var walletsTotalBalanceStore: TotalBalanceStoreV2 {
    if let _walletsTotalBalanceStore {
      return _walletsTotalBalanceStore
    }
    let store = TotalBalanceStoreV2(processedBalanceStore: processedBalanceStore)
    _walletsTotalBalanceStore = store
    return store
  }
  
  private weak var _backgroundUpdateUpdater: BackgroundUpdateUpdater?
  public var backgroundUpdateUpdater: BackgroundUpdateUpdater {
    if let backgroundUpdateUpdater = _backgroundUpdateUpdater {
      return backgroundUpdateUpdater
    } else {
      let backgroundUpdateUpdater = BackgroundUpdateUpdater(
        backgroundUpdateStore: backgroundUpdateStoreV2,
        walletsStore: walletsAssembly.walletsStoreV2,
        streamingAPI: apiAssembly.streamingTonAPIClient()
      )
      _backgroundUpdateUpdater = backgroundUpdateUpdater
      return backgroundUpdateUpdater
    }
  }
  
  private weak var _backgroundUpdateStoreV2: BackgroundUpdateStoreV2?
  public var backgroundUpdateStoreV2: BackgroundUpdateStoreV2 {
    if let backgroundUpdateStore = _backgroundUpdateStoreV2 {
      return backgroundUpdateStore
    } else {
      let backgroundUpdateStore = BackgroundUpdateStoreV2()
      _backgroundUpdateStoreV2 = backgroundUpdateStore
      return backgroundUpdateStore
    }
  }
}
