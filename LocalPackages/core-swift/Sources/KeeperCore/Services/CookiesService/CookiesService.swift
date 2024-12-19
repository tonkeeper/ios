import Foundation
import WebKit

public protocol CookiesService: AnyObject {
  func saveCookiesState(hosts: [String], wallet: Wallet) async
  func restoreCookies(for wallet: Wallet)

  func removeAllStorageCookies(for wallet: Wallet)
  func removeCookies(for host: String, wallet: Wallet) async
  func removeStorageCookie(_ cookie: HTTPCookie) async
  func removeAllSessionCookies(_ completion: @escaping (() -> Void))
}

final class CookiesServiceImplementation: CookiesService {

  private let cookiesRepository: CookiesRepository

  private var webDataStore: WKWebsiteDataStore { .default() }

  init(cookiesRepository: CookiesRepository) {
    self.cookiesRepository = cookiesRepository
  }

  func saveCookiesState(hosts: [String], wallet: Wallet) async {
    let cookies = await webDataStore.httpCookieStore.allCookies()
    let filteredCookies: [CookieBridgeModel] = cookies.compactMap {
      guard hosts.contains($0.domain) else {
        return nil
      }
      return CookieBridgeModel(cookie: $0)
    }

    guard !filteredCookies.isEmpty else { return }

    try? cookiesRepository.save(filteredCookies, for: wallet)
  }

  func restoreCookies(for wallet: Wallet) {
    let bridgeCookies = cookiesRepository.fetchCookies(for: wallet)
    bridgeCookies.forEach {
      guard let cookie = $0.asHttpCookie else {
        return
      }
      webDataStore.httpCookieStore.setCookie(cookie)
    }
  }

  func removeCookies(for host: String, wallet: Wallet) async {
    let cookies = await webDataStore.httpCookieStore.allCookies()
    await cookies.asyncForEach { cookie in
      guard host.contains(cookie.domain) else {
        return
      }

      let bridgeCookie = CookieBridgeModel(cookie: cookie)
      try? self.cookiesRepository.remove(bridgeCookie, for: wallet)
      await self.removeStorageCookie(cookie)
    }
  }

  func removeAllSessionCookies(_ completion: @escaping (() -> Void)) {
    DispatchQueue.main.async {
      self.webDataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
        self.webDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records, completionHandler: completion)
      }
    }
  }

  func removeStorageCookie(_ cookie: HTTPCookie) async {
    await webDataStore.httpCookieStore.deleteCookie(cookie)
  }

  func removeAllStorageCookies(for wallet: Wallet) {
    try? cookiesRepository.removeCookies(for: wallet)
  }
}
