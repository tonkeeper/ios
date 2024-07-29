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
  
  private weak var _balanceStore: BalanceStore?
  public var balanceStore: BalanceStore {
    if let _balanceStore {
      return _balanceStore
    }
    let store = BalanceStore(walletsStore: walletsAssembly.walletsStore,
                               repository: repositoriesAssembly.walletBalanceRepositoryV2()
    )
    _balanceStore = store
    return store
  }
  
  private weak var _convertedBalanceStore: ConvertedBalanceStore?
    public var convertedBalanceStore: ConvertedBalanceStore {
      if let _convertedBalanceStore {
        return _convertedBalanceStore
      }
      let store = ConvertedBalanceStore(

        balanceStore: balanceStore,
        tonRatesStore: storesAssembly.tonRatesStore,
        currencyStore: storesAssembly.currencyStore

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
      walletsStore: walletsAssembly.walletsStore,
      balanceStore: balanceStore,
      tonRatesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore,
      stakingPoolsStore: storesAssembly.stackingPoolsStore
    )
    _processedBalanceStore = store
    return store
  }
  
  private weak var _walletsTotalBalanceStore: TotalBalanceStore?
  public var walletsTotalBalanceStore: TotalBalanceStore {
    if let _walletsTotalBalanceStore {
      return _walletsTotalBalanceStore
    }
    let store = TotalBalanceStore(processedBalanceStore: processedBalanceStore)
    _walletsTotalBalanceStore = store
    return store
  }
  
  private weak var _backgroundUpdateUpdater: BackgroundUpdateUpdater?
  public var backgroundUpdateUpdater: BackgroundUpdateUpdater {
    if let backgroundUpdateUpdater = _backgroundUpdateUpdater {
      return backgroundUpdateUpdater
    } else {
      let backgroundUpdateUpdater = BackgroundUpdateUpdater(
        backgroundUpdateStore: backgroundUpdateStore,
        walletsStore: walletsAssembly.walletsStore,
        streamingAPI: apiAssembly.streamingTonAPIClient()
      )
      _backgroundUpdateUpdater = backgroundUpdateUpdater
      return backgroundUpdateUpdater
    }
  }
  
  private weak var _backgroundUpdateStore: BackgroundUpdateStore?
  public var backgroundUpdateStore: BackgroundUpdateStore {
    if let backgroundUpdateStore = _backgroundUpdateStore {
      return backgroundUpdateStore
    } else {
      let backgroundUpdateStore = BackgroundUpdateStore()
      _backgroundUpdateStore = backgroundUpdateStore
      return backgroundUpdateStore
    }
  }
}
