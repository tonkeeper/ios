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
  private let buySellProvider: BuySellProvider
  
  init(configuration: Configuration,
       knownAccountsStore: KnownAccountsStore,
       deeplinkParser: DeeplinkParser,
       keeperInfoRepository: KeeperInfoRepository,
       mnemonicsRepository: MnemonicsRepository,
       buySellProvider: BuySellProvider) {
    self.configuration = configuration
    self.knownAccountsStore = knownAccountsStore
    self.deeplinkParser = deeplinkParser
    self.keeperInfoRepository = keeperInfoRepository
    self.mnemonicsRepository = mnemonicsRepository
    self.buySellProvider = buySellProvider
  }

  public func loadConfigurations() {
    buySellProvider.load()
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
