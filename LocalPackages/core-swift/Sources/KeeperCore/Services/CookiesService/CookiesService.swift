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

  private var cookiesStorage: HTTPCookieStorage { .shared }

  init(cookiesRepository: CookiesRepositoryProtocol) {
    self.cookiesRepository = cookiesRepository
  }

  func saveCookiesState(hosts: [String], wallet: Wallet) {
    guard #unavailable(iOS 17) else {
      return
    }
    Task {
      let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
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
      WKWebsiteDataStore.default().httpCookieStore.setCookie(cookie)
    }
  }

  func removeCookies(for host: String, wallet: Wallet) {
    guard #unavailable(iOS 17) else {
      webDataStore(wallet: wallet).removeData(host: host)
      return
    }

    WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
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
    guard #unavailable(iOS 17) else {
      return
    }

    let dataStore = WKWebsiteDataStore.default()
    DispatchQueue.main.async {
      dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
        dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) {
          completion()
        }
      }
    }
  }

  func removeStorageCookie(_ cookie: HTTPCookie) {
    Task {
      await WKWebsiteDataStore.default().httpCookieStore.deleteCookie(cookie)
    }
  }

  func removeAllStorageCookies(for wallet: Wallet) {
    cookiesRepository.removeCookies(for: wallet)
  }
}

extension CookiesService {

  func webDataStore(wallet: Wallet) -> TKWebDataStore {
    TKWebDataStore(wallet: wallet)
  }
}
