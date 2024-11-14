import Foundation

public final class RootController {
  public enum State {
    case onboarding
    case main(wallets: [Wallet], activeWallet: Wallet)
  }

  private let configuration: Configuration
  private let deeplinkParser: DeeplinkParser
  private let keeperInfoRepository: KeeperInfoRepository
  private let mnemonicsRepository: MnemonicsRepository
  private let buySellProvider: BuySellProvider
  private let knownAccountsProvider: KnownAccountsProvider
  
  init(configuration: Configuration,
       deeplinkParser: DeeplinkParser,
       keeperInfoRepository: KeeperInfoRepository,
       mnemonicsRepository: MnemonicsRepository,
       buySellProvider: BuySellProvider,
       knownAccountsProvider: KnownAccountsProvider) {
    self.configuration = configuration
    self.deeplinkParser = deeplinkParser
    self.keeperInfoRepository = keeperInfoRepository
    self.mnemonicsRepository = mnemonicsRepository
    self.buySellProvider = buySellProvider
    self.knownAccountsProvider = knownAccountsProvider
  }

  public func loadConfigurations() {
    buySellProvider.load()
    knownAccountsProvider.load()
    Task {
      await configuration.loadConfiguration()
    }
  }
  
  public func parseDeeplink(string: String?) throws -> Deeplink {
    try deeplinkParser.parse(string: string)
  }
}
