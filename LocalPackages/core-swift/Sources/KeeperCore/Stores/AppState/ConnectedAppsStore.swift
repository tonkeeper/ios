import Foundation

public final class ConnectedAppsStore: Store<ConnectedAppsStore.Event, [TonConnectApp]> {

  public enum Event {
    case didUpdateApps
  }

  private let walletsStore: WalletsStore
  private let tonConnectAppsStore: TonConnectAppsStore
  private let cookiesService: CookiesService

  public init(
    walletsStore: WalletsStore,
    tonConnectAppsStore: TonConnectAppsStore,
    cookiesService: CookiesService) {
      self.walletsStore = walletsStore
      self.tonConnectAppsStore = tonConnectAppsStore
      self.cookiesService = cookiesService

      super.init(state: [])

      bindDependencies()
  }

  public override func createInitialState() -> [TonConnectApp] {
    calculateState()
  }

  private func bindDependencies() {
    tonConnectAppsStore.addObserver(self)
    walletsStore.addObserver(self) { observer, event in
      switch event {
      case .willChangeActiveWallet(let wallet):
        observer.saveCookiesState(wallet: wallet)
      case .didChangeActiveWallet(let wallet):
        observer.restoreCookieSession(wallet: wallet)
      case .didDeleteWallet(let wallet):
        observer.clearCookies(for: wallet)
      default:
        break
      }
    }
  }

  private func calculateState() -> [TonConnectApp] {
    do {
      let connectedApps = try tonConnectAppsStore.connectedApps(forWallet: walletsStore.activeWallet)
        .apps
      return connectedApps
    } catch {
      return []
    }
  }

  private func restoreCookieSession(wallet: Wallet) {
    Task {
      await clearCookieSession()
      await restoreCookiesState(wallet: wallet)

      update()
    }
  }

  private func saveCookiesState(wallet: Wallet) {
    cookiesService.removeAllStorageCookies(for: wallet)

    Task {
      guard let connectedApps = try? tonConnectAppsStore.connectedApps(forWallet: wallet).apps else {
        return
      }
      await cookiesService.saveCookiesState(hosts: connectedApps.map { $0.manifest.host }, wallet: wallet)
    }
  }

  private func restoreCookiesState(wallet: Wallet) async {
    await cookiesService.restoreCookies(for: wallet)
  }

  private func clearCookieSession() async {
    await cookiesService.removeAllSessionCookies()
  }

  private func clearCookies(for wallet: Wallet) {
    cookiesService.removeAllStorageCookies(for: wallet)
  }

  public func deleteApp(_ app: TonConnectApp) async {
    guard let wallet = try? walletsStore.activeWallet else {
      return
    }

    await cookiesService.removeCookies(for: app.manifest.host, wallet: wallet)
    tonConnectAppsStore.deleteConnectedApp(wallet: wallet, app: app)
    update()
  }

  private func update() {
    updateState { [weak self] state in
      guard let self else {
        return nil
      }
      return StateUpdate(newState: calculateState())
    } completion: { [weak self] _ in
      guard let self else {
        return
      }
      sendEvent(.didUpdateApps)
    }
  }
}

// MARK: -  TonConnectAppsStoreObserver

extension ConnectedAppsStore: TonConnectAppsStoreObserver {

  public func didGetTonConnectAppsStoreEvent(_ event: TonConnectAppsStoreEvent) {
    update()
  }
}
