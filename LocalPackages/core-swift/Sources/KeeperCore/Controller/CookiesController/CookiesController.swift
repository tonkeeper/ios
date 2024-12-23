import Foundation
import WebKit

public final class CookiesController {

  private let walletsStore: WalletsStore
  private let cookiesService: CookiesService
  private let tonConnectAppsStore: TonConnectAppsStore

  public init(walletsStore: WalletsStore,
              cookiesService: CookiesService,
              tonConnectAppsStore: TonConnectAppsStore) {
    self.walletsStore = walletsStore
    self.cookiesService = cookiesService
    self.tonConnectAppsStore = tonConnectAppsStore
  }

  public func start() {
    walletsStore.addObserver(self) { observer, event in
      switch event {
      case let .didChangeActiveWallet(previousWallet, activeWallet):
        Task {
          await observer.saveCookiesState(for: previousWallet)
          await observer.restoreCookieSession(wallet: activeWallet)
        }
      case .didDeleteWallet(let wallet):
        observer.clearCookies(for: wallet)
      default:
        break
      }
    }

    tonConnectAppsStore.addObserver(self)
  }

  private func saveCookiesState(for wallet: Wallet) async {
    clearCookies(for: wallet)

    guard let connectedApps = try? tonConnectAppsStore.connectedApps(forWallet: wallet).apps else {
      return
    }

    let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
    let hosts = connectedApps.map { $0.manifest.host }
    try? cookiesService.saveCookiesState(hosts: hosts, cookies: cookies, wallet: wallet)
  }

  private func restoreCookieSession(wallet: Wallet) async {
    let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
    await cookies.asyncForEach { cookie in
     await WKWebsiteDataStore.default().httpCookieStore.deleteCookie(cookie)
    }

    let localCookies = cookiesService.fetchLocalCookies(for: wallet)
    await localCookies.asyncForEach {
      guard let cookie = $0.asHttpCookie else {
        return
      }

      await MainActor.run {
        WKWebsiteDataStore.default().httpCookieStore.setCookie(cookie)
      }
    }
  }

  private func clearCookies(for wallet: Wallet) {
    try? cookiesService.removeAllStorageCookies(for: wallet)
  }

  private func deleteApp(app: TonConnectApp, wallet: Wallet) {
    Task {
      let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
      await cookies.asyncForEach { cookie in
        guard app.manifest.host.contains(cookie.domain) else {
          return
        }

        try? cookiesService.remove(cookie: cookie, wallet: wallet)
        await WKWebsiteDataStore.default().httpCookieStore.deleteCookie(cookie)
      }
    }
  }
}

// MARK: -  TonConnectAppsStoreObserver

extension CookiesController: TonConnectAppsStoreObserver {

  public func didGetTonConnectAppsStoreEvent(_ event: TonConnectAppsStoreEvent) {
    switch event {
    case .didUpdateApps:
      break
    case let .didDisconnect(app, wallet):
      deleteApp(app: app, wallet: wallet)
    }
  }
}
