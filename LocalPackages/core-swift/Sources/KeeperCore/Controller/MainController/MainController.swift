import Foundation
import TonSwift

public final class MainController {

  public var didReceiveTonConnectRequest: ((TonConnect.AppRequest, Wallet, TonConnectApp) -> Void)?
  
  private var walletsStoreObservationToken: ObservationToken?
  private var backgroundUpdateStoreObservationToken: ObservationToken?
  private var updatesStarted = false
  
  private let backgroundUpdate: BackgroundUpdate
  private let tonConnectEventsStore: TonConnectEventsStore
  private let tonConnectService: TonConnectService
  private let deeplinkParser: DeeplinkParser
  
  private let balanceLoader: BalanceLoader
  private let internalNotificationsLoader: InternalNotificationsLoader
  
  init(backgroundUpdate: BackgroundUpdate,
       tonConnectEventsStore: TonConnectEventsStore,
       tonConnectService: TonConnectService,
       deeplinkParser: DeeplinkParser,
       balanceLoader: BalanceLoader,
       internalNotificationsLoader: InternalNotificationsLoader) {
    self.backgroundUpdate = backgroundUpdate
    self.tonConnectEventsStore = tonConnectEventsStore
    self.tonConnectService = tonConnectService
    self.deeplinkParser = deeplinkParser
    self.balanceLoader = balanceLoader
    self.internalNotificationsLoader = internalNotificationsLoader
    
    backgroundUpdate.addEventObserver(self) { [weak self] observer, wallet, event in
      DispatchQueue.main.async {
        self?.balanceLoader.loadWalletBalance(wallet: wallet)
      }
    }
  }
  
  public func start() {
    startUpdates()
    internalNotificationsLoader.loadNotifications()
  }
  
  public func stop() {
    stopUpdates()
  }
  
  public func startUpdates() {
    guard !updatesStarted else { return }
    balanceLoader.loadActiveWalletBalance()
    balanceLoader.startActiveWalletBalanceReload()
    backgroundUpdate.start()
    Task {
      await tonConnectEventsStore.addObserver(self)
      await tonConnectEventsStore.start()
      await MainActor.run {
        updatesStarted = true
      }
    }
  }
  
  public func stopUpdates() {
    balanceLoader.stopActiveWalletBalanceReload()
    backgroundUpdate.stop()
    Task {
      await tonConnectEventsStore.stop()
      await tonConnectEventsStore.removeObserver(self)
      await MainActor.run {
        updatesStarted = false
      }
    }
  }
  
  public func handleTonConnectDeeplink(_ parameters: TonConnectParameters) async throws -> (TonConnectParameters, TonConnectManifest) {
    try await tonConnectService.loadTonConnectConfiguration(with: parameters)
  }
  public func parseDeeplink(deeplink: String?) throws -> Deeplink {
    try deeplinkParser.parse(string: deeplink)
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
