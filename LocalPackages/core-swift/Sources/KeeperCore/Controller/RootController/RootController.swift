import Foundation

public final class RootController {
  public enum State {
    case onboarding
    case main(wallets: [Wallet], activeWallet: Wallet)
  }

  private let walletsService: WalletsService
  private let remoteConfigurationStore: ConfigurationStore
  private let knownAccountsStore: KnownAccountsStore
  private let deeplinkParser: DeeplinkParser
  private let keeperInfoRepository: KeeperInfoRepository
  private let mnemonicsRepository: MnemonicsRepository
  private let buySellMethodsService: BuySellMethodsService
  private let locationService: LocationService
  
  init(walletsService: WalletsService,
       remoteConfigurationStore: ConfigurationStore,
       knownAccountsStore: KnownAccountsStore,
       deeplinkParser: DeeplinkParser,
       keeperInfoRepository: KeeperInfoRepository,
       mnemonicsRepository: MnemonicsRepository,
       buySellMethodsService: BuySellMethodsService,
       locationService: LocationService) {
    self.walletsService = walletsService
    self.remoteConfigurationStore = remoteConfigurationStore
    self.knownAccountsStore = knownAccountsStore
    self.deeplinkParser = deeplinkParser
    self.keeperInfoRepository = keeperInfoRepository
    self.mnemonicsRepository = mnemonicsRepository
    self.buySellMethodsService = buySellMethodsService
    self.locationService = locationService
  }
  
  public func getState() -> State {
    do {
      let wallets = try walletsService.getWallets()
      let activeWallet = try walletsService.getActiveWallet()
      return .main(wallets: wallets, activeWallet: activeWallet)
    } catch {
      return .onboarding
    }
  }
  
  public func loadConfiguration() {
    Task {
      try await remoteConfigurationStore.load()
    }
  }
  
  public func loadKnownAccounts() {
    Task {
      try await knownAccountsStore.load()
    }
  }
  
  public func loadBuySellMethods() {
    Task {
      let countryCode = try await locationService.getCountryCodeByIp()
      let methods = try await buySellMethodsService.loadFiatMethods(countryCode: countryCode)
      try? buySellMethodsService.saveFiatMethods(methods)
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
