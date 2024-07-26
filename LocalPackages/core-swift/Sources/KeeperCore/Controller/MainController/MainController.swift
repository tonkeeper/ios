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
  
  private let walletsStore: WalletsStoreV2
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
  
  private let walletBalanceLoader: WalletBalanceLoaderV2
  private let tonRatesLoader: TonRatesLoaderV2
  private let internalNotificationsLoader: InternalNotificationsLoader
  private let nftsLoader: NftsLoader
  
  private var walletsBalanceLoadTimer: Timer?
  private var tonRatesLoadTimer: Timer?

  private var state = State()
  
  private var nftStateTask: Task<Void, Never>?

  init(walletsStore: WalletsStoreV2,
       accountNFTService: AccountNFTService,
       backgroundUpdateUpdater: BackgroundUpdateUpdater,
       tonConnectEventsStore: TonConnectEventsStore,
       knownAccountsStore: KnownAccountsStore,
       balanceStore: BalanceStore,
       dnsService: DNSService,
       tonConnectService: TonConnectService,
       deeplinkParser: DeeplinkParser,
       apiProvider: APIProvider,
       walletBalanceLoader: WalletBalanceLoaderV2,
       tonRatesLoader: TonRatesLoaderV2,
       nftsLoader: NftsLoader,
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
    self.walletBalanceLoader = walletBalanceLoader
    self.tonRatesLoader = tonRatesLoader
    self.nftsLoader = nftsLoader
    self.internalNotificationsLoader = internalNotificationsLoader
    
    walletsStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      guard newState.activeWallet != oldState?.activeWallet else { return }
      Task {
        await observer.stopBackgroundUpdate()
        await observer.startBackgroundUpdate()
      }
    }
  }
  
  deinit {
    stopTonRatesLoadTimer()
    stopWalletBalancesLoadTimer()
  }
  
  public func start() {
    backgroundUpdateUpdater.addEventObserver(self) { observer, event in
      observer.walletBalanceLoader.reloadBalance(address: FriendlyAddress(
        address: event.accountAddress,
        testOnly: false,
        bounceable: false))
    }
    startTonRatesLoadTimer()
    startWalletBalancesLoadTimer()
    internalNotificationsLoader.loadNotifications(platform: "ios", version: "4.1.0", lang: "en")
    Task {
      await tonConnectEventsStore.addObserver(self)
    }
    Task {
      await self.nftsLoader.loadNfts(wallet: self.walletsStore.getState().activeWallet)
    }
    walletsStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      Task {
        await self.nftsLoader.loadNfts(wallet: newState.activeWallet)
      }
    }
  }
  
  private func startTonRatesLoadTimer() {
    self.tonRatesLoadTimer?.invalidate()
    let timer = Timer(timeInterval: 15, repeats: true, block: { [weak self] _ in
      self?.tonRatesLoader.reloadRates()
    })
    RunLoop.main.add(timer, forMode: .common)
    self.tonRatesLoadTimer = timer
  }
  
  private func stopTonRatesLoadTimer() {
    self.tonRatesLoadTimer?.invalidate()
  }
  
  private func startWalletBalancesLoadTimer() {
    self.walletsBalanceLoadTimer?.invalidate()
    let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
      guard let self else { return }
      self.walletBalanceLoader.reloadBalance()
      Task {
        await self.nftsLoader.loadNfts(wallet: self.walletsStore.getState().activeWallet)
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    self.walletsBalanceLoadTimer = timer
  }
  
  private func stopWalletBalancesLoadTimer() {
    self.walletsBalanceLoadTimer?.invalidate()
  }
    
  public func startBackgroundUpdate() async {
    let activeWallet = await walletsStore.getState().activeWallet
    guard let address = try? activeWallet.friendlyAddress else { return }
    await backgroundUpdateUpdater.start(addresses: [address.address])
    await tonConnectEventsStore.start()
  }
  
  public func stopBackgroundUpdate() async {
    await backgroundUpdateUpdater.stop()
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
    for wallet in await walletsStore.getState().wallets {
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
