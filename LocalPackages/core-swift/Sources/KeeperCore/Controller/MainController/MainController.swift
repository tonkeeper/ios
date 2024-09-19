import Foundation
import TonSwift

public final class MainController {
  
  public enum Error: Swift.Error {
    case failedResolveRecipient(recipient: String)
  }
  
  actor State {
    var nftsUpdateTask: Task<(), Never>?
    
    func setNftsUpdateTask(_ task: Task<(), Never>?) {
      self.nftsUpdateTask = task
    }
  }
  
  public var didReceiveTonConnectRequest: ((TonConnect.AppRequest, Wallet, TonConnectApp) -> Void)?
  
  private var walletsStoreObservationToken: ObservationToken?
  private var backgroundUpdateStoreObservationToken: ObservationToken?
  
  private let appInfoProvider: AppInfoProvider
  private let walletsStore: WalletsStore
  private let accountNFTService: AccountNFTService
  private let backgroundUpdateUpdater: BackgroundUpdateUpdater
  private let tonConnectEventsStore: TonConnectEventsStore
  private let knownAccountsStore: KnownAccountsStore
  private let dnsService: DNSService
  private let tonConnectService: TonConnectService
  private let deeplinkParser: DeeplinkParser
  // TODO: wrap to service
  private let apiProvider: APIProvider
  
  private let walletStateLoader: WalletStateLoader
  private let internalNotificationsLoader: InternalNotificationsLoader
  
  private var tonRatesLoadTimer: Timer?

  private var state = State()
  
  private var nftStateTask: Task<Void, Never>?

  init(appInfoProvider: AppInfoProvider,
       walletsStore: WalletsStore,
       accountNFTService: AccountNFTService,
       backgroundUpdateUpdater: BackgroundUpdateUpdater,
       tonConnectEventsStore: TonConnectEventsStore,
       knownAccountsStore: KnownAccountsStore,
       dnsService: DNSService,
       tonConnectService: TonConnectService,
       deeplinkParser: DeeplinkParser,
       apiProvider: APIProvider,
       walletStateLoader: WalletStateLoader,
       internalNotificationsLoader: InternalNotificationsLoader) {
    self.appInfoProvider = appInfoProvider
    self.walletsStore = walletsStore
    self.accountNFTService = accountNFTService
    self.backgroundUpdateUpdater = backgroundUpdateUpdater
    self.tonConnectEventsStore = tonConnectEventsStore
    self.knownAccountsStore = knownAccountsStore
    self.dnsService = dnsService
    self.tonConnectService = tonConnectService
    self.deeplinkParser = deeplinkParser
    self.apiProvider = apiProvider
    self.walletStateLoader = walletStateLoader
    self.internalNotificationsLoader = internalNotificationsLoader
  }
  
  public func start() {
    startUpdates()
    internalNotificationsLoader.loadNotifications()
  }
  
  public func stop() {
    stopUpdates()
  }
  
  public func startUpdates() {
    walletStateLoader.startStateReload()
    Task {
      await backgroundUpdateUpdater.start()
    }
    Task {
      await tonConnectEventsStore.start()
    }
  }
  
  public func stopUpdates() {
    walletStateLoader.stopStateReload()
    Task {
      await backgroundUpdateUpdater.stop()
    }
    Task {
      await tonConnectEventsStore.stop()
    }
  }
  
  public func handleTonConnectDeeplink(_ parameters: TonConnectParameters) async throws -> (TonConnectParameters, TonConnectManifest) {
    try await tonConnectService.loadTonConnectConfiguration(with: parameters)
  }
  public func parseDeeplink(deeplink: String?) throws -> Deeplink {
    try deeplinkParser.parse(string: deeplink)
  }
  
  public func resolveSend(recipient: String, jettonAddress: Address?) async throws -> Recipient {
    let recipient = try await resolveRecipient(recipient)
    return recipient
  }
  
  private func resolveRecipient(_ recipient: String) async throws -> Recipient {
    let knownAccounts = (try? await knownAccountsStore.getKnownAccounts()) ?? []
    if let friendlyAddress = try? FriendlyAddress(string: recipient) {
      let isMemoRequired = knownAccounts.first(where: { $0.address == friendlyAddress.address })?.requireMemo ?? false
      return Recipient(recipientAddress: .friendly(friendlyAddress), isMemoRequired: isMemoRequired)
    } else if let rawAddress = try? Address.parse(recipient) {
      let isMemoRequired = knownAccounts.first(where: { $0.address == rawAddress })?.requireMemo ?? false
      return Recipient(recipientAddress: .raw(rawAddress), isMemoRequired: isMemoRequired)
    } else if let domain = try? await dnsService.resolveDomainName(
      recipient,
      isTestnet: false) {
      return Recipient(recipientAddress: .domain(domain),
                       isMemoRequired: knownAccounts.first(where: { $0.address == domain.friendlyAddress.address })?.requireMemo ?? false)
    } else {
      throw Error.failedResolveRecipient(recipient: recipient)
    }
  }
}

extension MainController: TonConnectEventsStoreObserver {
  public func didGetTonConnectEventsStoreEvent(_ event: TonConnectEventsStore.Event) {
    switch event {
    case .request(let request, let wallet, let app):
      Task { @MainActor in
        didReceiveTonConnectRequest?(request, wallet, app)
      }
    }
  }
}
