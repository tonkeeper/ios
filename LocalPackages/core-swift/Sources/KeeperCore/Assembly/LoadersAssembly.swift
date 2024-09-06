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
  
  private weak var _tonRatesLoaderV2: TonRatesLoaderV2?
  var tonRatesLoaderV2: TonRatesLoaderV2 {
    if let _tonRatesLoaderV2 {
      return _tonRatesLoaderV2
    }
    let loader = TonRatesLoaderV2(
      tonRatesStore: storesAssembly.tonRatesStore,
      ratesService: servicesAssembly.ratesService(),
      currencyStore: storesAssembly.currencyStore
    )
    _tonRatesLoaderV2 = loader
    return loader
  }
  
  private weak var _nftsLoader: NftsLoader?
  var nftsLoader: NftsLoader {
    if let _nftsLoader {
      return _nftsLoader
    }
    let loader = NftsLoader(
      nftsStore: storesAssembly.nftsStore,
      nftsService: servicesAssembly.accountNftService()
    )
    _nftsLoader = loader
    return loader
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
      currencyStore: storesAssembly.currencyStoreV3,
      walletsStore: storesAssembly.walletsStore,
      ratesStore: storesAssembly.tonRatesStoreV3,
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
