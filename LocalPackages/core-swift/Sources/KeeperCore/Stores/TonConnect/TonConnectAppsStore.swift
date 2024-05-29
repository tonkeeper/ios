import Foundation
import TonSwift

enum TonConnectAppsStoreEvent {
  case didUpdateApps
}

protocol TonConnectAppsStoreObserver: AnyObject {
  func didGetTonConnectAppsStoreEvent(_ event: TonConnectAppsStoreEvent)
}

public final class TonConnectAppsStore {
  
  public enum ConnectResult {
    case response(Data)
    case error(TonConnect.ConnectEventError.Error)
  }
  
  public enum SendTransactionResult {
    case response(Data)
    case error(TonConnect.SendTransactionResponseError.ErrorCode)
  }
  
  private let tonConnectService: TonConnectService
  
  init(tonConnectService: TonConnectService) {
    self.tonConnectService = tonConnectService
  }
  
  public func connect(wallet: Wallet,
                      parameters: TonConnectParameters,
                      manifest: TonConnectManifest) async throws {
    let connectEventSuccessResponse = try tonConnectService.buildConnectEventSuccessResponse(
      wallet: wallet,
      parameters: parameters,
      manifest: manifest
    )
    let sessionCrypto = try TonConnectSessionCrypto()
    let encrypted = try tonConnectService.encryptSuccessResponse(
      connectEventSuccessResponse,
      parameters: parameters,
      sessionCrypto: sessionCrypto
    )
    try await tonConnectService.confirmConnectionRequest(
      body: encrypted,
      sessionCrypto: sessionCrypto,
      parameters: parameters
    )
    try tonConnectService.storeConnectedApp(
      wallet: wallet,
      sessionCrypto: sessionCrypto,
      parameters: parameters,
      manifest: manifest
    )
    await MainActor.run {
      notifyObservers(event:.didUpdateApps)
    }
  }
  
  public func connectBridgeDapp(wallet: Wallet,
                                parameters: TonConnectParameters,
                                manifest: TonConnectManifest) -> ConnectResult {
    do {
      let connectEventSuccessResponse = try tonConnectService.buildConnectEventSuccessResponse(
        wallet: wallet,
        parameters: parameters,
        manifest: manifest
      )
      let response = try JSONEncoder().encode(connectEventSuccessResponse)
      let sessionCrypto = try TonConnectSessionCrypto()
      try tonConnectService.storeConnectedApp(
        wallet: wallet,
        sessionCrypto: sessionCrypto,
        parameters: parameters,
        manifest: manifest
      )
      notifyObservers(event:.didUpdateApps)
      return .response(response)
    } catch {
      return .error(.unknownError)
    }
  }
  
  public func reconnectBridgeDapp(wallet: Wallet, appUrl: URL?) -> ConnectResult {
    guard let app = try? connectedApps(forWallet: wallet).apps.first(where: {
      $0.manifest.url.host == appUrl?.host
    }) else {
      return .error(.unknownApp)
    }
    do {
      let response = try tonConnectService.buildReconnectConnectEventSuccessResponse(
        wallet: wallet,
        manifest: app.manifest
      )
      let responseData = try JSONEncoder().encode(response)
      return .response(responseData)
    } catch {
      return .error(.unknownError)
    }
  }
  
  public func disconnect(wallet: Wallet, appUrl: URL?) throws {
    guard let app = try? connectedApps(forWallet: wallet).apps.first(where: {
      $0.manifest.url.host == appUrl?.host
    }) else {
      return
    }
    try? tonConnectService.disconnectApp(app, wallet: wallet)
    notifyObservers(event:.didUpdateApps)
  }
  
  public func connectedApps(forWallet wallet: Wallet) throws -> TonConnectApps {
    try tonConnectService.getConnectedApps(forWallet: wallet)
  }
  
  public func getLastEventId() -> String? {
    try? tonConnectService.getLastEventId()
  }
  
  public func saveLastEventId(_ lastEventId: String?) {
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
