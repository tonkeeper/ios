import Foundation

public protocol CookiesService: AnyObject {
    func fetchLocalCookies(for wallet: Wallet) -> [CookieBridgeModel]
    func saveState(hosts: [String], cookies: [HTTPCookie], wallet: Wallet) throws

    func removeAllStorageCookies(for wallet: Wallet) throws
}

final class CookiesServiceImplementation: CookiesService {
    private let cookiesRepository: CookiesRepository

    init(cookiesRepository: CookiesRepository) {
        self.cookiesRepository = cookiesRepository
    }

    // MARK: -  Fetch

    func fetchLocalCookies(for wallet: Wallet) -> [CookieBridgeModel] {
        cookiesRepository.fetchCookies(for: wallet)
    }

    // MARK: -  Save

    func saveState(hosts: [String], cookies: [HTTPCookie], wallet: Wallet) throws {
        let composedCookies: [CookieBridgeModel] = cookies.compactMap {
            guard hosts.contains($0.domain) else {
                return nil
            }
            return CookieBridgeModel(cookie: $0)
        }

        try cookiesRepository.save(composedCookies, for: wallet)
    }

    // MARK: -  Remove

    func removeAllStorageCookies(for wallet: Wallet) throws {
        try cookiesRepository.removeCookies(for: wallet)
    }
}
