import Foundation

public final class BrowserConnectedController {
  
  public var didUpdateApps: (() -> Void)?
  
  public struct ConnectedApp {
    public let url: URL
    public let name: String
    public let iconURL: URL?
  }
  
  private let walletsStore: WalletsStore
  private let tonConnectAppsStore: TonConnectAppsStore
  
  init(walletsStore: WalletsStore,
       tonConnectAppsStore: TonConnectAppsStore) {
    self.walletsStore = walletsStore
    self.tonConnectAppsStore = tonConnectAppsStore
  }
  
  public func start() {
    tonConnectAppsStore.addObserver(self)
  }
  
  public func getConnectedApps() -> [ConnectedApp] {
    do {
      let connectedApps = try tonConnectAppsStore.connectedApps(forWallet: walletsStore.activeWallet)
        .apps
        .map { item in
          ConnectedApp(
            url: item.manifest.url,
            name: item.manifest.name,
            iconURL: item.manifest.iconUrl
          )
        }
      return connectedApps
    } catch {
      return []
    }
  }
}

extension BrowserConnectedController: TonConnectAppsStoreObserver {
  func didGetTonConnectAppsStoreEvent(_ event: TonConnectAppsStoreEvent) {
    didUpdateApps?()
  }
}
