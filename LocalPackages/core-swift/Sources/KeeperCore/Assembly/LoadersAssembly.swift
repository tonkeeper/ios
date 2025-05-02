import Foundation
import TonSwift

public final class LoadersAssembly {
  
  private let servicesAssembly: ServicesAssembly
  private let storesAssembly: StoresAssembly
  private let tonkeeperAPIAssembly: TonkeeperAPIAssembly
  private let apiAssembly: APIAssembly
  private let knownAccountsAssembly: KnownAccountsAssembly
  private let tronAssembly: TronUSDTAssembly
  
  init(servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly,
       tonkeeperAPIAssembly: TonkeeperAPIAssembly,
       apiAssembly: APIAssembly,
       knownAccountsAssembly: KnownAccountsAssembly,
       tronAssembly: TronUSDTAssembly) {
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
    self.tonkeeperAPIAssembly = tonkeeperAPIAssembly
    self.apiAssembly = apiAssembly
    self.knownAccountsAssembly = knownAccountsAssembly
    self.tronAssembly = tronAssembly
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
  
  public func historyAllEventsPaginationLoader(wallet: Wallet) -> HistoryPaginationLoader {
    historyPaginationLoader(
      wallet: wallet,
      loader: HistoryListAllEventsLoader(
        historyService: servicesAssembly.historyService(),
        tonProofTokenService: servicesAssembly.tonProofTokenService(),
        tronAPI: tronAssembly.api
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
  
  public func historyTronUSDTEventsPaginationLoader(wallet: Wallet) -> HistoryPaginationLoader {
    historyPaginationLoader(
      wallet: wallet,
      loader: HistoryListTronUSDTEventsLoader(
        historyService: servicesAssembly.historyService(),
        tonProofTokenService: servicesAssembly.tonProofTokenService(),
        tronAPI: tronAssembly.api
      )
    )
  }
  
  func historyPaginationLoader(wallet: Wallet,
                               loader: HistoryListLoader) -> HistoryPaginationLoader {
    HistoryPaginationLoader(
      wallet: wallet,
      loader: loader,
      nftService: servicesAssembly.nftService()
    )
  }

  private weak var _balanceLoader: BalanceLoader?
  public var balanceLoader: BalanceLoader {
    if let _balanceLoader {
      return _balanceLoader
    }
    let loader = BalanceLoader(
      walletStore: storesAssembly.walletsStore,
      currencyStore: storesAssembly.currencyStore,
      ratesStore: storesAssembly.tonRatesStore,
      ratesService: servicesAssembly.ratesService(),
      walletStateLoaderProvider: { self.walletBalanceLoaders(wallet: $0) }
    )
    _balanceLoader = loader
    return loader
  }
  
  private var _walletBalanceLoaders = [Wallet: Weak<WalletBalanceLoader>]()
  public func walletBalanceLoaders(wallet: Wallet) -> WalletBalanceLoader {
    if let weakWrapper = _walletBalanceLoaders[wallet],
       let store = weakWrapper.value {
      return store
    }
    let store = WalletBalanceLoader(
      wallet: wallet,
      balanceStore: storesAssembly.balanceStore,
      stakingPoolsStore: storesAssembly.stackingPoolsStore,
      walletNFTSStore: storesAssembly.walletNFTsStore(wallet: wallet, nftService: servicesAssembly.accountNftService()),
      balanceService: servicesAssembly.balanceService(),
      stackingService: servicesAssembly.stackingService(),
      accountNFTService: servicesAssembly.accountNftService()
    )
    _walletBalanceLoaders[wallet] = Weak(value: store)
    return store
  }
  
  public func recipientResolver() -> RecipientResolver {
    RecipientResolverImplementation(
      knownAccountsProvider: knownAccountsAssembly.knownAccountsProvider,
      dnsService: servicesAssembly.dnsService()
    )
  }

  public func insufficientFundsValidator() -> InsufficientFundsValidator {
    InsufficientFundsValidatorImplementation(
      balanceStore: storesAssembly.balanceStore,
      apiProvider: apiAssembly.apiProvider
    )
  }
}
