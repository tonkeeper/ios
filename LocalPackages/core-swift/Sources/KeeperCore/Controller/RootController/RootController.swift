import Foundation

public final class RootController {
  public enum State {
    case onboarding
    case main(wallets: [Wallet], activeWallet: Wallet)
  }
  
  public var didLoadStoryToShow: ((_ story: Story) -> Void)?

  private let configuration: Configuration
  private let deeplinkParser: DeeplinkParser
  private let keeperInfoRepository: KeeperInfoRepository
  private let mnemonicsRepository: MnemonicsRepository
  private let buySellProvider: BuySellProvider
  private let knownAccountsProvider: KnownAccountsProvider
  private let storyProvider: StoryProvider
  
  init(configuration: Configuration,
       deeplinkParser: DeeplinkParser,
       keeperInfoRepository: KeeperInfoRepository,
       mnemonicsRepository: MnemonicsRepository,
       buySellProvider: BuySellProvider,
       knownAccountsProvider: KnownAccountsProvider,
       storyProvider: StoryProvider) {
    self.configuration = configuration
    self.deeplinkParser = deeplinkParser
    self.keeperInfoRepository = keeperInfoRepository
    self.mnemonicsRepository = mnemonicsRepository
    self.buySellProvider = buySellProvider
    self.knownAccountsProvider = knownAccountsProvider
    self.storyProvider = storyProvider
  }

  public func loadConfigurations() {
    buySellProvider.load()
    knownAccountsProvider.load()
    Task {
      await configuration.loadConfiguration()
    }
  }
  
  public func loadStoryToShow() {
    storyProvider.loadStoryToShow()
    storyProvider.addUpdateObserver(self) { observer in
      DispatchQueue.main.async {
        let state = observer.storyProvider.state
        switch state {
        case .story(let story):
          self.didLoadStoryToShow?(story)
        default:
          break
        }
      }
    }
  }
  
  public func parseDeeplink(string: String?) throws -> Deeplink {
    try deeplinkParser.parse(string: string)
  }
}
