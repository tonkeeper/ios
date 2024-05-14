import Foundation
import TonSwift

public final class MainController {
  
  actor State {
    var nftsUpdateTask: Task<(), Never>?
    
    func setNftsUpdateTask(_ task: Task<(), Never>?) {
      self.nftsUpdateTask = task
    }
  }
  
  public var didUpdateNftsAvailability: ((Bool) -> Void)?
  public var didUpdateBrowserAvailability: ((Bool) -> Void)?
  public var didReceiveTonConnectRequest: ((TonConnect.AppRequest, Wallet, TonConnectApp) -> Void)?
  
  private var walletsStoreObservationToken: ObservationToken?
  private var backgroundUpdateStoreObservationToken: ObservationToken?
  
  private let walletsStore: WalletsStore
  private let accountNFTService: AccountNFTService
  private let backgroundUpdateStore: BackgroundUpdateStore
  private let tonConnectEventsStore: TonConnectEventsStore
  private let knownAccountsStore: KnownAccountsStore
  private let balanceStore: BalanceStore
  private let dnsService: DNSService
  private let tonConnectService: TonConnectService
  private let deeplinkParser: DeeplinkParser
  // TODO: wrap to service
  private let apiProvider: APIProvider
  
  private var state = State()
  
  private var nftStateTask: Task<Void, Never>?

  init(walletsStore: WalletsStore, 
       accountNFTService: AccountNFTService,
       backgroundUpdateStore: BackgroundUpdateStore,
       tonConnectEventsStore: TonConnectEventsStore,
       knownAccountsStore: KnownAccountsStore,
       balanceStore: BalanceStore,
       dnsService: DNSService,
       tonConnectService: TonConnectService,
       deeplinkParser: DeeplinkParser,
       apiProvider: APIProvider) {
    self.walletsStore = walletsStore
    self.accountNFTService = accountNFTService
    self.backgroundUpdateStore = backgroundUpdateStore
    self.tonConnectEventsStore = tonConnectEventsStore
    self.knownAccountsStore = knownAccountsStore
    self.balanceStore = balanceStore
    self.dnsService = dnsService
    self.tonConnectService = tonConnectService
    self.deeplinkParser = deeplinkParser
    self.apiProvider = apiProvider
  }
  
  deinit {
    walletsStoreObservationToken?.cancel()
    backgroundUpdateStoreObservationToken?.cancel()
  }
  
  public func start() async {
    _ = await backgroundUpdateStore.addEventObserver(self) { observer, state in
      switch state {
      case .didUpdateState(let backgroundUpdateState):
        switch backgroundUpdateState {
        case .connected:
          Task { await observer.updateNfts() }
        default: break
        }
      case .didReceiveUpdateEvent(let backgroundUpdateEvent):
        Task {
          guard try backgroundUpdateEvent.accountAddress == observer.walletsStore.activeWallet.address else { return }
          await observer.updateNfts()
        }
      }
    }
    
    _ = walletsStore.addEventObserver(self) { observer, event in
      switch event {
      case .didAddWallets:
        Task { await observer.startBackgroundUpdate() }
      case .didUpdateActiveWallet:
        self.didUpdateActiveWallet()
        Task { await observer.updateNfts() }
      default: break
      }
    }
    
    await tonConnectEventsStore.addObserver(self)
    
    await startBackgroundUpdate()
    didUpdateActiveWallet()
  }
  
  public func updateNfts() async {}
  
  public func startBackgroundUpdate() async {
    await backgroundUpdateStore.start(addresses: walletsStore.wallets.compactMap { try? $0.address })
    await tonConnectEventsStore.start()
  }
  
  public func stopBackgroundUpdate() async {
    await backgroundUpdateStore.stop()
    await tonConnectEventsStore.stop()
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
    for wallet in walletsStore.wallets {
      guard let balance = try? balanceStore.getBalance(wallet: wallet).balance else {
        continue
      }
      guard let jettonItem =  balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonInfo })?.item else {
        continue
      }
      return jettonItem
    }
    return nil
  }
  
  private func didUpdateActiveWallet() {
    let isBrowserAvailable = !walletsStore.activeWallet.isWatchonly
    didUpdateBrowserAvailability?(isBrowserAvailable)
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
