import Foundation

public final class RootController {
  public enum State {
    case onboarding
    case main(wallets: [Wallet], activeWallet: Wallet)
  }

  private let configuration: Configuration
  private let knownAccountsStore: KnownAccountsStore
  private let deeplinkParser: DeeplinkParser
  private let keeperInfoRepository: KeeperInfoRepository
  private let mnemonicsRepository: MnemonicsRepository
  private let fiatMethodsLoader: FiatMethodsLoader
  
  init(configuration: Configuration,
       knownAccountsStore: KnownAccountsStore,
       deeplinkParser: DeeplinkParser,
       keeperInfoRepository: KeeperInfoRepository,
       mnemonicsRepository: MnemonicsRepository,
       fiatMethodsLoader: FiatMethodsLoader) {
    self.configuration = configuration
    self.knownAccountsStore = knownAccountsStore
    self.deeplinkParser = deeplinkParser
    self.keeperInfoRepository = keeperInfoRepository
    self.mnemonicsRepository = mnemonicsRepository
    self.fiatMethodsLoader = fiatMethodsLoader
  }
  
  public func loadFiatMethods(isMarketRegionPickerAvailable: Bool) {
    fiatMethodsLoader.loadFiatMethods(isMarketRegionPickerAvailable: isMarketRegionPickerAvailable)
  }
  
  public func loadConfigurations() {
    Task {
      await configuration.loadConfiguration()
    }
    Task {
      try await knownAccountsStore.load()
    }
  }
  
  public func parseDeeplink(string: String?) throws -> Deeplink {
    try deeplinkParser.parse(string: string)
  }
}
