import Foundation

public final class RootAssembly {
  public let repositoriesAssembly: RepositoriesAssembly
  private let servicesAssembly: ServicesAssembly
  public let storesAssembly: StoresAssembly
  private let coreAssembly: CoreAssembly
  public let formattersAssembly: FormattersAssembly
  public let walletsUpdateAssembly: WalletsUpdateAssembly
  private let configurationAssembly: ConfigurationAssembly
  public let passcodeAssembly: PasscodeAssembly
  private let apiAssembly: APIAssembly
  private let loadersAssembly: LoadersAssembly

  init(repositoriesAssembly: RepositoriesAssembly,
       coreAssembly: CoreAssembly,
       servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly,
       formattersAssembly: FormattersAssembly,
       walletsUpdateAssembly: WalletsUpdateAssembly,
       configurationAssembly: ConfigurationAssembly,
       passcodeAssembly: PasscodeAssembly,
       apiAssembly: APIAssembly,
       loadersAssembly: LoadersAssembly) {
    self.repositoriesAssembly = repositoriesAssembly
    self.coreAssembly = coreAssembly
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
    self.formattersAssembly = formattersAssembly
    self.walletsUpdateAssembly = walletsUpdateAssembly
    self.configurationAssembly = configurationAssembly
    self.passcodeAssembly = passcodeAssembly
    self.apiAssembly = apiAssembly
    self.loadersAssembly = loadersAssembly
  }
  
  private var _rootController: RootController?
  public func rootController() -> RootController {
    if let rootController = _rootController {
      return rootController
    } else {
      let rootController = RootController(
        walletsService: servicesAssembly.walletsService(),
        remoteConfigurationStore: configurationAssembly.remoteConfigurationStore,
        knownAccountsStore: storesAssembly.knownAccountsStore,
        deeplinkParser: DefaultDeeplinkParser(parsers: [
          TonkeeperDeeplinkParser(),
          TonDeeplinkParser(),
          TonConnectDeeplinkParser()
        ]),
        keeperInfoRepository: repositoriesAssembly.keeperInfoRepository(),
        mnemonicsRepository: repositoriesAssembly.mnemonicsRepository(),
        buySellMethodsService: servicesAssembly.buySellMethodsService(),
        locationService: servicesAssembly.locationService()
      )
      self._rootController = rootController
      return rootController
    }
  }
  
  public func migrationController(sharedCacheURL: URL,
                                  keychainAccessGroupIdentifier: String) -> MigrationController {
    MigrationController(
      sharedCacheURL: sharedCacheURL,
      keychainAccessGroupIdentifier: keychainAccessGroupIdentifier,
      rootAssembly: self
    )
  }
  
  public func onboardingAssembly() -> OnboardingAssembly {
    OnboardingAssembly(
      walletsUpdateAssembly: walletsUpdateAssembly,
      passcodeAssembly: passcodeAssembly,
      storesAssembly: storesAssembly
    )
  }
  
  public func mainAssembly(dependencies: MainAssembly.Dependencies) -> MainAssembly {
    let walletAssembly = WalletAssembly(
      servicesAssembly: servicesAssembly,
      storesAssembly: storesAssembly,
      walletUpdateAssembly: walletsUpdateAssembly,
      wallets: dependencies.wallets,
      activeWallet: dependencies.activeWallet)
    let tonConnectAssembly = TonConnectAssembly(
      repositoriesAssembly: repositoriesAssembly,
      servicesAssembly: servicesAssembly,
      storesAssembly: storesAssembly,
      walletsAssembly: walletAssembly,
      apiAssembly: apiAssembly,
      coreAssembly: coreAssembly,
      formattersAssembly: formattersAssembly
    )
    return MainAssembly(
      repositoriesAssembly: repositoriesAssembly,
      walletAssembly: walletAssembly,
      walletUpdateAssembly: walletsUpdateAssembly,
      servicesAssembly: servicesAssembly,
      storesAssembly: storesAssembly,
      formattersAssembly: formattersAssembly,
      configurationAssembly: configurationAssembly,
      passcodeAssembly: passcodeAssembly,
      tonConnectAssembly: tonConnectAssembly,
      apiAssembly: apiAssembly,
      loadersAssembly: loadersAssembly
    )
  }
}
