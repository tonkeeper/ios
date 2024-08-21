import Foundation
import TonSwift

public final class MainController {
  
  actor State {
    var nftsUpdateTask: Task<(), Never>?
    
    func setNftsUpdateTask(_ task: Task<(), Never>?) {
      self.nftsUpdateTask = task
    }
  }
  
  public var didReceiveTonConnectRequest: ((TonConnect.AppRequest, Wallet, TonConnectApp) -> Void)?
  
  private var walletsStoreObservationToken: ObservationToken?
  private var backgroundUpdateStoreObservationToken: ObservationToken?
  
  private let walletsStore: WalletsStore
  private let accountNFTService: AccountNFTService
  private let backgroundUpdateUpdater: BackgroundUpdateUpdater
  private let tonConnectEventsStore: TonConnectEventsStore
  private let knownAccountsStore: KnownAccountsStore
  private let balanceStore: BalanceStore
  private let dnsService: DNSService
  private let tonConnectService: TonConnectService
  private let deeplinkParser: DeeplinkParser
  // TODO: wrap to service
  private let apiProvider: APIProvider
  
  private let walletStateLoader: WalletStateLoader
  private let tonRatesLoader: TonRatesLoaderV2
  private let internalNotificationsLoader: InternalNotificationsLoader
  
  private var tonRatesLoadTimer: Timer?

  private var state = State()
  
  private var nftStateTask: Task<Void, Never>?

  init(walletsStore: WalletsStore,
       accountNFTService: AccountNFTService,
       backgroundUpdateUpdater: BackgroundUpdateUpdater,
       tonConnectEventsStore: TonConnectEventsStore,
       knownAccountsStore: KnownAccountsStore,
       balanceStore: BalanceStore,
       dnsService: DNSService,
       tonConnectService: TonConnectService,
       deeplinkParser: DeeplinkParser,
       apiProvider: APIProvider,
       walletStateLoader: WalletStateLoader,
       tonRatesLoader: TonRatesLoaderV2,
       internalNotificationsLoader: InternalNotificationsLoader) {
    self.walletsStore = walletsStore
    self.accountNFTService = accountNFTService
    self.backgroundUpdateUpdater = backgroundUpdateUpdater
    self.tonConnectEventsStore = tonConnectEventsStore
    self.knownAccountsStore = knownAccountsStore
    self.balanceStore = balanceStore
    self.dnsService = dnsService
    self.tonConnectService = tonConnectService
    self.deeplinkParser = deeplinkParser
    self.apiProvider = apiProvider
    self.walletStateLoader = walletStateLoader
    self.tonRatesLoader = tonRatesLoader
    self.internalNotificationsLoader = internalNotificationsLoader
  }
  
  deinit {
    stopUpdates()
  }
  
  public func start() {
    startUpdates()
  }
  
  public func startUpdates() {
    walletStateLoader.startStateReload()
    walletStateLoader.loadNFTs()
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
  
  public func handleTonConnectDeeplink(_ deeplink: TonConnectDeeplink) async throws -> (TonConnectParameters, TonConnectManifest) {
    try await tonConnectService.loadTonConnectConfiguration(with: deeplink)
  }
  
  public func parseDeeplink(deeplink: String?) throws -> Deeplink {
    try deeplinkParser.parse(string: deeplink)
  }
  
  public func resolveRecipient(_ recipient: String) async -> Recipient? {
    let inputRecipient: Recipient?
    let knownAccounts = (try? await knownAccountsStore.getKnownAccounts()) ?? []
    if let friendlyAddress = try? FriendlyAddress(string: recipient) {
      inputRecipient = Recipient(
        recipientAddress: .friendly(
          friendlyAddress
        ),
        isMemoRequired: knownAccounts.first(where: { $0.address == friendlyAddress.address })?.requireMemo ?? false
      )
    } else if let rawAddress = try? Address.parse(recipient) {
      inputRecipient = Recipient(
        recipientAddress: .raw(
          rawAddress
        ),
        isMemoRequired: knownAccounts.first(where: { $0.address == rawAddress })?.requireMemo ?? false
      )
    } else {
      inputRecipient = nil
    }
    return inputRecipient
  }
  
  public func resolveJetton(jettonAddress: Address) async -> JettonItem? {
    let jettonInfo: JettonInfo
    if let mainnetJettonInfo = try? await apiProvider.api(false).resolveJetton(address: jettonAddress) {
      jettonInfo = mainnetJettonInfo
    } else if let testnetJettonInfo = try? await apiProvider.api(true).resolveJetton(address: jettonAddress) {
      jettonInfo = testnetJettonInfo
    } else {
      return nil
    }
    for wallet in await walletsStore.getState().wallets {
      guard let address = try? wallet.friendlyAddress,
            let balance = await balanceStore.getState()[address]?.walletBalance else {
        continue
      }
      guard let jettonItem =  balance.balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonInfo })?.item else {
        continue
      }
      return jettonItem
    }
    return nil
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
