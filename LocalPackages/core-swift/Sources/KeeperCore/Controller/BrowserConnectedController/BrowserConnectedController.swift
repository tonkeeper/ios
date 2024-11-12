import Foundation

public final class BrowserConnectedController {
  
  public var didUpdateApps: (() -> Void)?
  
  private let walletsStore: WalletsStore
  private let tonConnectAppsStore: TonConnectAppsStore
  
  init(walletsStore: WalletsStore,
       tonConnectAppsStore: TonConnectAppsStore) {
    self.walletsStore = walletsStore
    self.tonConnectAppsStore = tonConnectAppsStore
  }
  
  public func start() {
    tonConnectAppsStore.addObserver(self)
    walletsStore.addObserver(self) { observer, event in
      observer.didUpdateApps?()
    }
  }
  
  public func getConnectedApps() -> [TonConnectApp] {
    do {
      let connectedApps = try tonConnectAppsStore.connectedApps(forWallet: walletsStore.activeWallet)
        .apps
      return connectedApps
    } catch {
      return []
    }
  }
  
  public func deleteApp(_ app: TonConnectApp) {
    guard let wallet = try? walletsStore.activeWallet else { return }
    tonConnectAppsStore.deleteConnectedApp(wallet: wallet, app: app)
    didUpdateApps?()
  }
}

extension BrowserConnectedController: TonConnectAppsStoreObserver {
  public func didGetTonConnectAppsStoreEvent(_ event: TonConnectAppsStoreEvent) {
    didUpdateApps?()
  }
}
