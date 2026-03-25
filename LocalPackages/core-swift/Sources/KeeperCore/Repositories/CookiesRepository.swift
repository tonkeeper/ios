import CoreComponents
import Foundation

public struct CookieBridgeModel: Codable, Equatable {
    let name: String
    let value: String
    let expiresDate: Date?
    let domain: String
    let path: String

    public var asHttpCookie: HTTPCookie? {
        HTTPCookie(
            properties: [
                .name: name,
                .value: value,
                .expires: expiresDate ?? Date(),
                .domain: domain,
                .path: path,
            ]
        )
    }

    public init(cookie: HTTPCookie) {
        name = cookie.name
        value = cookie.value
        expiresDate = cookie.expiresDate
        domain = cookie.domain
        path = cookie.path
    }
}

public protocol CookiesRepository {
    func save(_ cookies: [CookieBridgeModel], for wallet: Wallet) throws
    func fetchCookies(for wallet: Wallet) -> [CookieBridgeModel]
    func remove(_ cookie: CookieBridgeModel, for wallet: Wallet) throws
    func removeCookies(for wallet: Wallet) throws
}

struct CookiesRepositoryImplementation: CookiesRepository {
    private let fileVault: FileSystemVault<[CookieBridgeModel], String>

    init(fileVault: FileSystemVault<[CookieBridgeModel], String>) {
        self.fileVault = fileVault
    }

    func save(_ cookies: [CookieBridgeModel], for wallet: Wallet) throws {
        let key = try wallet.friendlyAddress.toString()
        try fileVault.saveItem(cookies, key: key)
    }

    func fetchCookies(for wallet: Wallet) -> [CookieBridgeModel] {
        do {
            let key = try wallet.friendlyAddress.toString()
            return try fileVault.loadItem(key: key)
        } catch {
            return []
        }
    }

    func remove(_ cookie: CookieBridgeModel, for wallet: Wallet) throws {
        let key = try wallet.friendlyAddress.toString()
        var cookies = try fileVault.loadItem(key: key)
        if let index = cookies.firstIndex(of: cookie) {
            cookies.remove(at: index)
        }
        try fileVault.saveItem(cookies, key: key)
    }

    func removeCookies(for wallet: Wallet) throws {
        let key = try wallet.friendlyAddress.toString()
        try fileVault.deleteItem(key: key)
    }
}
