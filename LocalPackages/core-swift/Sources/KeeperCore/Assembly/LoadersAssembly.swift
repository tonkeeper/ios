import Foundation
import TonSwift

public final class LoadersAssembly {
  
  private let servicesAssembly: ServicesAssembly
  private let storesAssembly: StoresAssembly
  private let tonkeeperAPIAssembly: TonkeeperAPIAssembly
  
  init(servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly,
       tonkeeperAPIAssembly: TonkeeperAPIAssembly) {
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
    self.tonkeeperAPIAssembly = tonkeeperAPIAssembly
  }
  
  var chartLoader: ChartV2Loader {
    ChartV2Loader(chartService: servicesAssembly.chartService())
  }
  
  private weak var _internalNotificationsLoader: InternalNotificationsLoader?
  var internalNotificationsLoader: InternalNotificationsLoader {
    if let _internalNotificationsLoader {
      return _internalNotificationsLoader
    }
    let loader = InternalNotificationsLoader(
      tonkeeperAPI: tonkeeperAPIAssembly.api,
      notificationsStore: storesAssembly.internalNotificationsStore
    )
    _internalNotificationsLoader = loader
    return loader
  }
  
  private weak var _fiatMethodsLoader: FiatMethodsLoader?
  func fiatMethodsLoader() -> FiatMethodsLoader {
    if let _fiatMethodsLoader {
      return _fiatMethodsLoader
    }
    let loader = FiatMethodsLoader(
      fiatMethodsStore: storesAssembly.fiatMethodsStore,
      buySellMethodsService: servicesAssembly.buySellMethodsService(),
      locationService: servicesAssembly.locationService()
    )
    _fiatMethodsLoader = loader
    return loader
  }
  
  public func historyAllEventsPaginationLoader(wallet: Wallet) -> HistoryPaginationLoader {
    historyPaginationLoader(
      wallet: wallet,
      loader: HistoryListAllEventsLoader(
        historyService: servicesAssembly.historyService()
      )
    )
  }
  
  public func historyTonEventsPaginationLoader(wallet: Wallet) -> HistoryPaginationLoader {
    historyPaginationLoader(
      wallet: wallet,
      loader: HistoryListTonEventsLoader(
        historyService: servicesAssembly.historyService()
      )
    )
  }
  
  public func historyJettonEventsPaginationLoader(wallet: Wallet,
                                                  jettonInfo: JettonInfo) -> HistoryPaginationLoader {
    historyPaginationLoader(
      wallet: wallet,
      loader: HistoryListJettonEventsLoader(jettonInfo: jettonInfo,
        historyService: servicesAssembly.historyService()
      )
    )
  }
  
  func historyPaginationLoader(wallet: Wallet,
                               loader: HistoryListLoader) -> HistoryPaginationLoader {
    HistoryPaginationLoader(
      wallet: wallet,
      loader: loader
    )
  }
  
  private weak var _walletStateLoader: WalletStateLoader?
  public var walletStateLoader: WalletStateLoader {
    if let _walletStateLoader {
      return _walletStateLoader
    }
    let loader = WalletStateLoader(
      balanceStore: storesAssembly.balanceStore,
      currencyStore: storesAssembly.currencyStore,
      walletsStore: storesAssembly.walletsStore,
      walletNFTSStore: storesAssembly.walletNFTsStore,
      ratesStore: storesAssembly.tonRatesStore,
      stakingPoolsStore: storesAssembly.stackingPoolsStore,
      balanceService: servicesAssembly.balanceService(),
      stackingService: servicesAssembly.stackingService(),
      accountNFTService: servicesAssembly.accountNftService(),
      ratesService: servicesAssembly.ratesService(),
      backgroundUpdateUpdater: storesAssembly.backgroundUpdateUpdater
    )
    _walletStateLoader = loader
    return loader
  }
}
