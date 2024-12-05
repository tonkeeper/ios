import Foundation
import WebKit

public protocol CookiesServiceProtocol: AnyObject {
  func saveCookiesState(hosts: [String], wallet: Wallet)
  func restoreCookies(for wallet: Wallet)

  func removeAllStorageCookies(for wallet: Wallet)
  func removeCookies(for host: String, wallet: Wallet)
  func removeStorageCookie(_ cookie: HTTPCookie)
  func removeAllSessionCookies(_ completion: @escaping (() -> Void))
}

final class CookiesService: CookiesServiceProtocol {

  private let cookiesRepository: CookiesRepositoryProtocol

  private var webDataStore: WKWebsiteDataStore { .default() }

  init(cookiesRepository: CookiesRepositoryProtocol) {
    self.cookiesRepository = cookiesRepository
  }

  func saveCookiesState(hosts: [String], wallet: Wallet) {
    Task {
      let cookies = await webDataStore.httpCookieStore.allCookies()
      let filteredCookies: [CookieBridgeModel] = cookies.compactMap {
        guard hosts.contains($0.domain) else {
          return nil
        }
        return CookieBridgeModel(cookie: $0)
      }

      guard !filteredCookies.isEmpty else { return }

      cookiesRepository.save(filteredCookies, for: wallet)
    }
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

  func removeCookies(for host: String, wallet: Wallet) {
    webDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
      guard let self else {
        return
      }

      cookies.forEach { cookie in
        guard host.contains(cookie.domain) else {
          return
        }

        let bridgeCookie = CookieBridgeModel(cookie: cookie)
        self.cookiesRepository.remove(bridgeCookie, for: wallet)
        self.removeStorageCookie(cookie)
      }
    }
  }

  func removeAllSessionCookies(_ completion: @escaping (() -> Void)) {
    DispatchQueue.main.async {
      self.webDataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
        self.webDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records, completionHandler: completion)
      }
    }
  }

  func removeStorageCookie(_ cookie: HTTPCookie) {
    Task {
      await webDataStore.httpCookieStore.deleteCookie(cookie)
    }
  }

  func removeAllStorageCookies(for wallet: Wallet) {
    cookiesRepository.removeCookies(for: wallet)
  }
}
