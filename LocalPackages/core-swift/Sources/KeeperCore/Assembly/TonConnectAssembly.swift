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
  
  public func tonConnectConfirmTransactionControllerBocProvider(signTransactionParams: [SendTransactionParam]) -> TonConnectConfirmTransactionControllerBocProvider {
    TonConnectConfirmTransactionControllerBocProvider(
      signTransactionParams: signTransactionParams,
      tonConnectService: tonConnectService()
    )
  }
  
  func tonConnectRepository() -> TonConnectRepository {
    TonConnectRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
  }
  
  public func tonConnectService() -> TonConnectService {
    TonConnectServiceImplementation(
      urlSession: .shared,
      apiClient: apiAssembly.tonConnectAPIClient(),
      mnemonicsRepository: repositoriesAssembly.mnemonicsRepository(),
      tonConnectAppsVault: coreAssembly.tonConnectAppsVault(),
      tonConnectRepository: tonConnectRepository(),
      walletBalanceRepository: repositoriesAssembly.walletBalanceRepository(),
      sendService: servicesAssembly.sendService()
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
        walletsStore: walletsAssembly.walletsStore,
        tonConnectAppsStore: tonConnectAppsStore
      )
      _tonConnectEventsStore = tonConnectEventsStore
      return tonConnectEventsStore
    }
  }
}
