import Foundation

public final class TonConnectAssembly {
  
  let repositoriesAssembly: RepositoriesAssembly
  let servicesAssembly: ServicesAssembly
  let storesAssembly: StoresAssembly
  let apiAssembly: APIAssembly
  let coreAssembly: CoreAssembly
  let formattersAssembly: FormattersAssembly
  let secureAssembly: SecureAssembly
  
  init(repositoriesAssembly: RepositoriesAssembly,
       servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly,
       apiAssembly: APIAssembly,
       coreAssembly: CoreAssembly,
       formattersAssembly: FormattersAssembly,
       secureAssembly: SecureAssembly) {
    self.repositoriesAssembly = repositoriesAssembly
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
    self.apiAssembly = apiAssembly
    self.coreAssembly = coreAssembly
    self.formattersAssembly = formattersAssembly
    self.secureAssembly = secureAssembly
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
      mnemonicsRepository: secureAssembly.mnemonicsRepository(),
      tonConnectAppsVault: coreAssembly.tonConnectAppsVault(),
      tonConnectAppsVaultLegacy: coreAssembly.tonConnectAppsVaultLegacy(),
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
        walletsStore: storesAssembly.walletsStore,
        tonConnectAppsStore: tonConnectAppsStore
      )
      _tonConnectEventsStore = tonConnectEventsStore
      return tonConnectEventsStore
    }
  }
}
