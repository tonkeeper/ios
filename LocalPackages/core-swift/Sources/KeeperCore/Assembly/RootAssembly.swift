import Foundation

public final class RootAssembly {
  public let appInfoProvider: AppInfoProvider
  public let repositoriesAssembly: RepositoriesAssembly
  private let servicesAssembly: ServicesAssembly
  public let storesAssembly: StoresAssembly
  public let coreAssembly: CoreAssembly
  public let formattersAssembly: FormattersAssembly
  public let mappersAssembly: MappersAssembly
  public let walletsUpdateAssembly: WalletsUpdateAssembly
  private let configurationAssembly: ConfigurationAssembly
  private let buySellAssembly: BuySellAssembly
  private let knownAccountsAssembly: KnownAccountsAssembly
  private let apiAssembly: APIAssembly
  private let loadersAssembly: LoadersAssembly
  public let backgroundUpdateAssembly: BackgroundUpdateAssembly
  public let rnAssembly: RNAssembly
  public let secureAssembly: SecureAssembly

  init(appInfoProvider: AppInfoProvider,
       repositoriesAssembly: RepositoriesAssembly,
       coreAssembly: CoreAssembly,
       servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly,
       formattersAssembly: FormattersAssembly,
       mappersAssembly: MappersAssembly,
       walletsUpdateAssembly: WalletsUpdateAssembly,
       configurationAssembly: ConfigurationAssembly,
       buySellAssembly: BuySellAssembly,
       knownAccountsAssembly: KnownAccountsAssembly,
       apiAssembly: APIAssembly,
       loadersAssembly: LoadersAssembly,
       backgroundUpdateAssembly: BackgroundUpdateAssembly,
       rnAssembly: RNAssembly,
       secureAssembly: SecureAssembly) {
    self.appInfoProvider = appInfoProvider
    self.repositoriesAssembly = repositoriesAssembly
    self.coreAssembly = coreAssembly
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
    self.formattersAssembly = formattersAssembly
    self.mappersAssembly = mappersAssembly
    self.walletsUpdateAssembly = walletsUpdateAssembly
    self.configurationAssembly = configurationAssembly
    self.buySellAssembly = buySellAssembly
    self.knownAccountsAssembly = knownAccountsAssembly
    self.apiAssembly = apiAssembly
    self.loadersAssembly = loadersAssembly
    self.backgroundUpdateAssembly = backgroundUpdateAssembly
    self.rnAssembly = rnAssembly
    self.secureAssembly = secureAssembly
  }
  
  private var _rootController: RootController?
  public func rootController() -> RootController {
    if let rootController = _rootController {
      return rootController
    } else {
      let rootController = RootController(
        configuration: configurationAssembly.configuration,
        deeplinkParser: DeeplinkParser(),
        keeperInfoRepository: repositoriesAssembly.keeperInfoRepository(),
        mnemonicsRepository: secureAssembly.mnemonicsRepository(),
        buySellProvider: buySellAssembly.buySellProvider,
        knownAccountsProvider: knownAccountsAssembly.knownAccountsProvider
      )
      self._rootController = rootController
      return rootController
    }
  }

  public func onboardingAssembly() -> OnboardingAssembly {
    OnboardingAssembly(
      walletsUpdateAssembly: walletsUpdateAssembly,
      storesAssembly: storesAssembly
    )
  }
  
  public func mainAssembly() -> MainAssembly {
    let tonConnectAssembly = TonConnectAssembly(
      repositoriesAssembly: repositoriesAssembly,
      servicesAssembly: servicesAssembly,
      storesAssembly: storesAssembly,
      apiAssembly: apiAssembly,
      coreAssembly: coreAssembly,
      formattersAssembly: formattersAssembly,
      secureAssembly: secureAssembly
    )
    return MainAssembly(
      appInfoProvider: appInfoProvider,
      repositoriesAssembly: repositoriesAssembly,
      walletUpdateAssembly: walletsUpdateAssembly,
      servicesAssembly: servicesAssembly,
      storesAssembly: storesAssembly,
      coreAssembly: coreAssembly,
      formattersAssembly: formattersAssembly,
      mappersAssembly: mappersAssembly,
      configurationAssembly: configurationAssembly,
      buySellAssembly: buySellAssembly,
      knownAccountsAssembly: knownAccountsAssembly,
      tonConnectAssembly: tonConnectAssembly,
      apiAssembly: apiAssembly,
      loadersAssembly: loadersAssembly,
      backgroundUpdateAssembly: backgroundUpdateAssembly,
      secureAssembly: secureAssembly,
      rnAssembly: rnAssembly
    )
  }
}
