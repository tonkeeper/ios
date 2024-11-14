import Foundation

public final class Assembly {
  public struct Dependencies {
    public let cacheURL: URL
    public let sharedCacheURL: URL
    public let appInfoProvider: AppInfoProvider
    public let seedProvider: () -> String
    
    public init(cacheURL: URL,
                sharedCacheURL: URL,
                appInfoProvider: AppInfoProvider,
                seedProvider: @escaping () -> String) {
      self.cacheURL = cacheURL
      self.sharedCacheURL = sharedCacheURL
      self.appInfoProvider = appInfoProvider
      self.seedProvider = seedProvider
    }
  }
  
  private let coreAssembly: CoreAssembly
  public lazy var repositoriesAssembly = RepositoriesAssembly(
    coreAssembly: coreAssembly
  )
  public lazy var secureAssembly = SecureAssembly(
    coreAssembly: coreAssembly
  )
  private lazy var configurationAssembly = ConfigurationAssembly(
    tonkeeperApiAssembly: tonkeeperApiAssembly,
    coreAssembly: coreAssembly
  )
  private lazy var buySellAssembly = BuySellAssembly(
    tonkeeperApiAssembly: tonkeeperApiAssembly,
    coreAssembly: coreAssembly
  )
  private lazy var knownAccountsAssembly = KnownAccountsAssembly(
    tonkeeperApiAssembly: tonkeeperApiAssembly,
    coreAssembly: coreAssembly
  )
  
  private lazy var backgroundUpdateAssembly = BackgroundUpdateAssembly(
    apiAssembly: apiAssembly,
    storesAssembly: storesAssembly,
    coreAssembly: coreAssembly
  )
  private lazy var apiAssembly = APIAssembly(configurationAssembly: configurationAssembly)
  private lazy var tonkeeperApiAssembly = TonkeeperAPIAssembly(appInfoProvider: dependencies.appInfoProvider)
  private lazy var locationAPIAssembly = LocationAPIAssembly()
  private lazy var scamAPIAssembly = ScamAPIAssembly(configurationAssembly: configurationAssembly)
  private lazy var servicesAssembly = ServicesAssembly(
    repositoriesAssembly: repositoriesAssembly, 
    apiAssembly: apiAssembly,
    tonkeeperAPIAssembly: tonkeeperApiAssembly,
    locationAPIAsembly: locationAPIAssembly,
    scamAPIAssembly: scamAPIAssembly,
    coreAssembly: coreAssembly,
    secureAssembly: secureAssembly,
    batteryAssembly: batteryAssembly
  )
  private lazy var storesAssembly = StoresAssembly(
    apiAssembly: apiAssembly,
    coreAssembly: coreAssembly,
    repositoriesAssembly: repositoriesAssembly
  )
  private lazy var loadersAssembly = LoadersAssembly(
    servicesAssembly: servicesAssembly,
    storesAssembly: storesAssembly,
    tonkeeperAPIAssembly: tonkeeperApiAssembly,
    apiAssembly: apiAssembly,
    knownAccountsAssembly: knownAccountsAssembly
  )
  private lazy var formattersAssembly = FormattersAssembly()
  private lazy var mappersAssembly = MappersAssembly(formattersAssembly: formattersAssembly)
  private var walletUpdateAssembly: WalletsUpdateAssembly {
    WalletsUpdateAssembly(
      storesAssembly: storesAssembly,
      servicesAssembly: servicesAssembly,
      repositoriesAssembly: repositoriesAssembly,
      formattersAssembly: formattersAssembly,
      secureAssembly: secureAssembly
    )
  }
  private lazy var rnAssembly = RNAssembly()
  private lazy var batteryAssembly = BatteryAssembly(
    batteryAPIAssembly: BatteryAPIAssembly(configurationAssembly: configurationAssembly),
    coreAssembly: coreAssembly
  )
  
  private let dependencies: Dependencies
  
  public init(dependencies: Dependencies) {
    self.dependencies = dependencies
    self.coreAssembly = CoreAssembly(
      cacheURL: dependencies.cacheURL,
      sharedCacheURL: dependencies.sharedCacheURL,
      appInfoProvider: dependencies.appInfoProvider,
      seedProvider: dependencies.seedProvider
    )
  }
}

public extension Assembly {
  func rootAssembly() -> RootAssembly {
    RootAssembly(
      appInfoProvider: dependencies.appInfoProvider,
      repositoriesAssembly: repositoriesAssembly,
      coreAssembly: coreAssembly,
      servicesAssembly: servicesAssembly,
      storesAssembly: storesAssembly,
      formattersAssembly: formattersAssembly,
      mappersAssembly: mappersAssembly,
      walletsUpdateAssembly: walletUpdateAssembly,
      configurationAssembly: configurationAssembly,
      buySellAssembly: buySellAssembly,
      batteryAssembly: batteryAssembly,
      knownAccountsAssembly: knownAccountsAssembly,
      apiAssembly: apiAssembly,
      loadersAssembly: loadersAssembly,
      backgroundUpdateAssembly: backgroundUpdateAssembly,
      rnAssembly: rnAssembly,
      secureAssembly: secureAssembly
    )
  }
  
  func widgetAssembly() -> WidgetAssembly {
    WidgetAssembly(
      repositoriesAssembly: repositoriesAssembly,
      coreAssembly: coreAssembly,
      servicesAssembly: servicesAssembly,
      storesAssembly: storesAssembly,
      formattersAssembly: formattersAssembly,
      walletsUpdateAssembly: walletUpdateAssembly,
      configurationAssembly: configurationAssembly,
      apiAssembly: apiAssembly,
      loadersAssembly: loadersAssembly
    )
  }
}
