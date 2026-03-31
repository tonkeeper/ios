import Foundation
import WebKit

public final class CookiesController {
    private let walletsStore: WalletsStore
    private let cookiesService: CookiesService
    private let tonConnectAppsStore: TonConnectAppsStore

    public init(
        walletsStore: WalletsStore,
        cookiesService: CookiesService,
        tonConnectAppsStore: TonConnectAppsStore
    ) {
        self.walletsStore = walletsStore
        self.cookiesService = cookiesService
        self.tonConnectAppsStore = tonConnectAppsStore
    }

    public func start() {
        walletsStore.addObserver(self) { observer, event in
            switch event {
            case let .didChangeActiveWallet(previousWallet, activeWallet):
                Task {
                    guard previousWallet != activeWallet else {
                        return
                    }

                    let httpCookies = await observer.saveCookiesState(for: previousWallet)
                    await observer.clearCurrentCookieSession(httpCookies)
                    await observer.restoreCookieSession(wallet: activeWallet)
                }
            case let .didDeleteWallet(wallet):
                observer.clearCookies(for: wallet)
            default:
                break
            }
        }

        tonConnectAppsStore.addObserver(self)
    }

    private func saveCookiesState(for wallet: Wallet) async -> [HTTPCookie] {
        clearCookies(for: wallet)

        guard let connectedApps = try? tonConnectAppsStore.connectedApps(forWallet: wallet).apps else {
            return []
        }

        let cookies = await fetchAllCookies()
        let hosts = connectedApps.map { $0.manifest.host }
        try? cookiesService.saveState(hosts: hosts, cookies: cookies, wallet: wallet)

        return cookies
    }

    private func clearCurrentCookieSession(_ cookies: [HTTPCookie]) async {
        await cookies.asyncForEach { cookie in
            await MainActor.run {
                WKWebsiteDataStore.default().httpCookieStore.delete(cookie)
            }
        }
    }

    private func restoreCookieSession(wallet: Wallet) async {
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
            let cookies = await fetchAllCookies()
            await cookies.asyncForEach { cookie in
                guard app.manifest.host.contains(cookie.domain) else {
                    return
                }

                try? cookiesService.remove(cookie: cookie, wallet: wallet)
                await MainActor.run {
                    WKWebsiteDataStore.default().httpCookieStore.delete(cookie)
                }
            }
        }
    }
}

private extension CookiesController {
    @MainActor
    private func fetchAllCookies() async -> [HTTPCookie] {
        await WKWebsiteDataStore.default().httpCookieStore.allCookies()
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
