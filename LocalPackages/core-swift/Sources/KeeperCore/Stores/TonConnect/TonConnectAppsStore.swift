import Foundation
import TonSwift

enum TonConnectAppsStoreEvent {
  case didUpdateApps
}

protocol TonConnectAppsStoreObserver: AnyObject {
  func didGetTonConnectAppsStoreEvent(_ event: TonConnectAppsStoreEvent)
}

final class TonConnectAppsStore {
  
  private let tonConnectService: TonConnectService
  
  init(tonConnectService: TonConnectService) {
    self.tonConnectService = tonConnectService
  }
  
  func connect(wallet: Wallet,
               parameters: TonConnectParameters,
               manifest: TonConnectManifest) async throws {
    try await tonConnectService.connect(
      wallet: wallet,
      parameters: parameters,
      manifest: manifest
    )
    await MainActor.run {
      notifyObservers(event:.didUpdateApps)
    }
  }
  
  func connectedApps(forWallet wallet: Wallet) throws -> TonConnectApps {
    try tonConnectService.getConnectedApps(forWallet: wallet)
  }
  
  func getLastEventId() -> String? {
    try? tonConnectService.getLastEventId()
  }
  
  func saveLastEventId(_ lastEventId: String?) {
    guard let lastEventId else { return }
    try? tonConnectService.saveLastEventId(lastEventId)
  }
  
  private var observers = [TonConnectAppsStoreObserverWrapper]()
  
  struct TonConnectAppsStoreObserverWrapper {
    weak var observer: TonConnectAppsStoreObserver?
  }
  
  func addObserver(_ observer: TonConnectAppsStoreObserver) {
    removeNilObservers()
    observers = observers + CollectionOfOne(TonConnectAppsStoreObserverWrapper(observer: observer))
  }
}

private extension TonConnectAppsStore {
  func removeNilObservers() {
    observers = observers.filter { $0.observer != nil }
  }
  
  func notifyObservers(event: TonConnectAppsStoreEvent) {
    observers.forEach { $0.observer?.didGetTonConnectAppsStoreEvent(event) }
  }
}
