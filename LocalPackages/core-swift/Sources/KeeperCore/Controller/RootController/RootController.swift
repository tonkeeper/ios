import Foundation

public final class RootController {
  public enum State {
    case onboarding
    case main(wallets: [Wallet], activeWallet: Wallet)
  }

  private let remoteConfigurationStore: ConfigurationLoader
  private let knownAccountsStore: KnownAccountsStore
  private let deeplinkParser: DeeplinkParser
  private let keeperInfoRepository: KeeperInfoRepository
  private let mnemonicsRepository: MnemonicsRepository
  private let fiatMethodsLoader: FiatMethodsLoader
  
  init(remoteConfigurationStore: ConfigurationLoader,
       knownAccountsStore: KnownAccountsStore,
       deeplinkParser: DeeplinkParser,
       keeperInfoRepository: KeeperInfoRepository,
       mnemonicsRepository: MnemonicsRepository,
       fiatMethodsLoader: FiatMethodsLoader) {
    self.remoteConfigurationStore = remoteConfigurationStore
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
      await remoteConfigurationStore.load()
    }
    Task {
      await remoteConfigurationStore.load()
    }
    Task {
      try await knownAccountsStore.load()
    }
  }
  
  public func parseDeeplink(string: String?) throws -> Deeplink {
    try deeplinkParser.parse(string: string)
  }
  
  public func logout() async throws {
    try await mnemonicsRepository.deleteAll()
    try keeperInfoRepository.removeKeeperInfo()
  }
}
