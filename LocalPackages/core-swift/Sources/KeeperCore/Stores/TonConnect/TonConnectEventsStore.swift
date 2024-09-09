import Foundation
import TonConnectAPI
import EventSource
import TonSwift

public protocol TonConnectEventsStoreObserver: AnyObject {
  func didGetTonConnectEventsStoreEvent(_ event: TonConnectEventsStore.Event)
}

public actor TonConnectEventsStore {
  public enum Event {
    case request(request: TonConnect.AppRequest, wallet: Wallet, app: TonConnectApp)
  }

  private var task: Task<Void, Error>?
  private let jsonDecoder = JSONDecoder()
  private var observers = [TonConnectEventsStoreObserverWrapper]()
  
  private let apiClient: TonConnectAPI.Client
  private let walletsStore: WalletsStoreV3
  private let tonConnectAppsStore: TonConnectAppsStore
  
  init(apiClient: TonConnectAPI.Client,
       walletsStore: WalletsStoreV3,
       tonConnectAppsStore: TonConnectAppsStore) {
    self.apiClient = apiClient
    self.walletsStore = walletsStore
    self.tonConnectAppsStore = tonConnectAppsStore
    
    tonConnectAppsStore.addObserver(self)
  }
  
  public func stop() {
    task?.cancel()
    task = nil
  }
  
  public func start() {
    task?.cancel()
    
    let task = Task {
      let ids = getApps().values
        .map { $0.apps.map { $0.keyPair.publicKey.hexString } }
        .flatMap { $0 }
        .joined(separator: ",")

      let errorParser = EventSourceDecodableErrorParser<TonConnectError>()
      let stream = try await EventSource.eventSource({
        let response = try await self.apiClient.events(
          query: .init(client_id: [ids], last_event_id: tonConnectAppsStore.getLastEventId())
        )
        return try response.ok.body.text_event_hyphen_stream
      }, errorParser: errorParser)
      for try await events in stream {
        handleEventSourceEvents(events)
      }
      guard !Task.isCancelled else { return }
      start()
    }
    self.task = task
  }
  
  public func addObserver(_ observer: TonConnectEventsStoreObserver) {
    removeNilObservers()
    observers = observers + CollectionOfOne(
      TonConnectEventsStoreObserverWrapper(observer: observer)
    )
  }
  
  public func removeObserver(_ observer: TonConnectEventsStoreObserver) {
    removeNilObservers()
    observers = observers.filter { $0.observer !== observer }
  }
}

private extension TonConnectEventsStore {
  func getApps() -> [Wallet: TonConnectApps] {
    let wallets = walletsStore.wallets
    
    var apps = [Wallet: TonConnectApps]()
    wallets.forEach { wallet in
      apps[wallet] = try? tonConnectAppsStore.connectedApps(forWallet: wallet)
    }
    return apps
  }
  
  func handleEventSourceEvents(_ events: [EventSource.Event]) {
    guard let event = events.last(where: { $0.event == "message" }),
          let data = event.data?.data(using: .utf8),
          let tonConnectEvent = try? jsonDecoder.decode(TonConnectEvent.self, from: data) else {
      return
    }
    tonConnectAppsStore.saveLastEventId(event.id)
    handleEvent(tonConnectEvent)
  }
  
  func handleEvent(_ tonConnectEvent: TonConnectEvent) {
    let walletsApps = getApps()
    walletsApps.forEach { walletApps in
      guard let app = walletApps.value.apps.first(where: { $0.clientId == tonConnectEvent.from }) else { return }
      
      do {
        let sessionCrypto = try TonConnectSessionCrypto(privateKey: app.keyPair.privateKey)
        guard let senderPublicKey = Data(hex: app.clientId),
              let message = Data(base64Encoded: tonConnectEvent.message) else { return }
        let decryptedMessage = try sessionCrypto
          .decrypt(message: message, senderPublicKey: senderPublicKey)
        let request = try jsonDecoder.decode(
          TonConnect.AppRequest.self,
          from: decryptedMessage
        )
        
        notifyObservers(with: .request(request: request, wallet: walletApps.key, app: app))
      } catch {
        print("Log: Failed to handle ton connect event \(tonConnectEvent), error: \(error)")
      }
    }
  }
  
  struct TonConnectEventsStoreObserverWrapper {
    weak var observer: TonConnectEventsStoreObserver?
  }
  
  func notifyObservers(with event: Event) {
    observers.forEach { $0.observer?.didGetTonConnectEventsStoreEvent(event) }
  }
  
  func removeNilObservers() {
    observers = observers.filter { $0.observer != nil }
  }
}

extension TonConnectEventsStore: TonConnectAppsStoreObserver {
  public nonisolated func didGetTonConnectAppsStoreEvent(_ event: TonConnectAppsStoreEvent) {
    switch event {
    case .didUpdateApps:
      Task {
        await start()
      }
    }
  }
}
