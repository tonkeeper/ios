import Foundation

public final class RootAssembly {
  public let repositoriesAssembly: RepositoriesAssembly
  private let servicesAssembly: ServicesAssembly
  public let storesAssembly: StoresAssembly
  public let coreAssembly: CoreAssembly
  public let formattersAssembly: FormattersAssembly
  public let walletsUpdateAssembly: WalletsUpdateAssembly
  private let configurationAssembly: ConfigurationAssembly
  public let passcodeAssembly: PasscodeAssembly
  private let apiAssembly: APIAssembly
  private let loadersAssembly: LoadersAssembly
  public let rnAssembly: RNAssembly

  init(repositoriesAssembly: RepositoriesAssembly,
       coreAssembly: CoreAssembly,
       servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly,
       formattersAssembly: FormattersAssembly,
       walletsUpdateAssembly: WalletsUpdateAssembly,
       configurationAssembly: ConfigurationAssembly,
       passcodeAssembly: PasscodeAssembly,
       apiAssembly: APIAssembly,
       loadersAssembly: LoadersAssembly,
       rnAssembly: RNAssembly) {
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
    self.rnAssembly = rnAssembly
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
        fiatMethodsLoader: loadersAssembly.fiatMethodsLoader()
      )
      self._rootController = rootController
      return rootController
    }
  }
  
  public func migrationController(sharedCacheURL: URL,
                                  keychainAccessGroupIdentifier: String,
                                  isTonkeeperX: Bool) -> MigrationController {
    MigrationController(
      sharedCacheURL: sharedCacheURL,
      keychainAccessGroupIdentifier: keychainAccessGroupIdentifier,
      rootAssembly: self,
      isTonkeeperX: isTonkeeperX
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
    let mainStoresAssembly = MainStoresAssembly(
      walletsAssembly: walletAssembly,
      repositoriesAssembly: repositoriesAssembly,
      servicesAssembly: servicesAssembly,
      storesAssembly: storesAssembly,
      apiAssembly: apiAssembly
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
      mainStoresAssembly: mainStoresAssembly,
      mainLoadersAssembly: MainLoadersAssembly(
        servicesAssembly: servicesAssembly, 
        storesAssembly: storesAssembly,
        mainStoresAssembly: mainStoresAssembly,
        walletAssembly: walletAssembly
      ),
      apiAssembly: apiAssembly,
      loadersAssembly: loadersAssembly
    )
  }
}
