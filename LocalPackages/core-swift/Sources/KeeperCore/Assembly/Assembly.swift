import Foundation

public final class Assembly {
  public struct Dependencies {
    public let cacheURL: URL
    public let sharedCacheURL: URL
    public let appInfoProvider: AppInfoProvider
    
    public init(cacheURL: URL,
                sharedCacheURL: URL,
                appInfoProvider: AppInfoProvider) {
      self.cacheURL = cacheURL
      self.sharedCacheURL = sharedCacheURL
      self.appInfoProvider = appInfoProvider
    }
  }
  
  private let coreAssembly: CoreAssembly
  public lazy var repositoriesAssembly = RepositoriesAssembly(coreAssembly: coreAssembly)
  private lazy var configurationAssembly = ConfigurationAssembly(
    tonkeeperApiAssembly: tonkeeperApiAssembly,
    coreAssembly: coreAssembly
  )
  private lazy var apiAssembly = APIAssembly(configurationAssembly: configurationAssembly)
  private lazy var tonkeeperApiAssembly = TonkeeperAPIAssembly(appInfoProvider: dependencies.appInfoProvider)
  private lazy var locationAPIAssembly = LocationAPIAssembly()
  private lazy var servicesAssembly = ServicesAssembly(
    repositoriesAssembly: repositoriesAssembly, 
    apiAssembly: apiAssembly,
    tonkeeperAPIAssembly: tonkeeperApiAssembly,
    locationAPIAsembly: locationAPIAssembly,
    coreAssembly: coreAssembly
  )
  private lazy var storesAssembly = StoresAssembly(
    servicesAssembly: servicesAssembly,
    apiAssembly: apiAssembly,
    coreAssembly: coreAssembly,
    repositoriesAssembly: repositoriesAssembly
  )
  private lazy var loadersAssembly = LoadersAssembly(
    servicesAssembly: servicesAssembly,
    storesAssembly: storesAssembly,
    tonkeeperAPIAssembly: tonkeeperApiAssembly
  )
  private lazy var formattersAssembly = FormattersAssembly()
  private var walletUpdateAssembly: WalletsUpdateAssembly {
    WalletsUpdateAssembly(
      storesAssembly: storesAssembly,
      servicesAssembly: servicesAssembly,
      repositoriesAssembly: repositoriesAssembly,
      formattersAssembly: formattersAssembly,
      rnAssembly: rnAssembly
    )
  }
  private lazy var passcodeAssembly = PasscodeAssembly(
    repositoriesAssembly: repositoriesAssembly,
    storesAssembly: storesAssembly
  )
  private lazy var rnAssembly = RNAssembly(coreAssembly: coreAssembly)
  
  private let dependencies: Dependencies
  
  public init(dependencies: Dependencies) {
    self.dependencies = dependencies
    self.coreAssembly = CoreAssembly(
      cacheURL: dependencies.cacheURL,
      sharedCacheURL: dependencies.sharedCacheURL,
      appInfoProvider: dependencies.appInfoProvider
    )
  }
}

public extension Assembly {
  func rootAssembly() -> RootAssembly {
    RootAssembly(
      repositoriesAssembly: repositoriesAssembly,
      coreAssembly: coreAssembly,
      servicesAssembly: servicesAssembly,
      storesAssembly: storesAssembly,
      formattersAssembly: formattersAssembly,
      walletsUpdateAssembly: walletUpdateAssembly,
      configurationAssembly: configurationAssembly,
      passcodeAssembly: passcodeAssembly,
      apiAssembly: apiAssembly,
      loadersAssembly: loadersAssembly,
      rnAssembly: rnAssembly
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
      passcodeAssembly: passcodeAssembly,
      apiAssembly: apiAssembly,
      loadersAssembly: loadersAssembly
    )
  }
}
