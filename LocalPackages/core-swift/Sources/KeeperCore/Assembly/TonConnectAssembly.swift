import Foundation

public final class TonConnectAssembly {
  
  let repositoriesAssembly: RepositoriesAssembly
  let servicesAssembly: ServicesAssembly
  let storesAssembly: StoresAssembly
  let walletsAssembly: WalletAssembly
  let apiAssembly: APIAssembly
  let coreAssembly: CoreAssembly
  let formattersAssembly: FormattersAssembly
  
  init(repositoriesAssembly: RepositoriesAssembly,
       servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly,
       walletsAssembly: WalletAssembly,
       apiAssembly: APIAssembly,
       coreAssembly: CoreAssembly,
       formattersAssembly: FormattersAssembly) {
    self.repositoriesAssembly = repositoriesAssembly
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
    self.walletsAssembly = walletsAssembly
    self.apiAssembly = apiAssembly
    self.coreAssembly = coreAssembly
    self.formattersAssembly = formattersAssembly
  }
  
  public func tonConnectConfirmationController(wallet: Wallet,
                                               signTransactionParams: [SendTransactionParam]) -> TonConnectConfirmationController {
    TonConnectConfirmationController(
      wallet: wallet,
      signTransactionParams: signTransactionParams,
      tonConnectService: tonConnectService(),
      sendService: servicesAssembly.sendService(),
      nftService: servicesAssembly.nftService(),
      ratesStore: storesAssembly.ratesStore,
      currencyStore: storesAssembly.currencyStore,
      tonConnectConfirmationMapper: TonConnectConfirmationMapper(
        historyListMapper: HistoryListMapper(
          dateFormatter: formattersAssembly.dateFormatter,
          amountFormatter: formattersAssembly.amountFormatter,
          amountMapper: AmountHistoryListEventAmountMapper(amountFormatter: formattersAssembly.amountFormatter)
        ),
        amountFormatter: formattersAssembly.amountFormatter
      )
    )
  }
  
  func tonConnectRepository() -> TonConnectRepository {
    TonConnectRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
  }
  
  public func tonConnectService() -> TonConnectService {
    TonConnectServiceImplementation(
      urlSession: .shared,
      apiClient: apiAssembly.tonConnectAPIClient(),
      mnemonicRepository: repositoriesAssembly.mnemonicRepository(),
      tonConnectAppsVault: coreAssembly.tonConnectAppsVault(),
      tonConnectRepository: tonConnectRepository()
    )
  }
  
  private weak var _tonConnectAppsStore: TonConnectAppsStore?
  public var tonConnectAppsStore: TonConnectAppsStore {
    if let tonConnectAppsStore = _tonConnectAppsStore {
      return tonConnectAppsStore
    } else {
      let tonConnectAppsStore = TonConnectAppsStore(
        tonConnectService: tonConnectService()
      )
      _tonConnectAppsStore = tonConnectAppsStore
      return tonConnectAppsStore
    }
  }
  
  private weak var _tonConnectEventsStore: TonConnectEventsStore?
  var tonConnectEventsStore: TonConnectEventsStore {
    if let tonConnectEventsStore = _tonConnectEventsStore {
      return tonConnectEventsStore
    } else {
      let tonConnectEventsStore = TonConnectEventsStore(
        apiClient: apiAssembly.tonConnectAPIClient(),
        walletsStore: walletsAssembly.walletStore,
        tonConnectAppsStore: tonConnectAppsStore
      )
      _tonConnectEventsStore = tonConnectEventsStore
      return tonConnectEventsStore
    }
  }
}
