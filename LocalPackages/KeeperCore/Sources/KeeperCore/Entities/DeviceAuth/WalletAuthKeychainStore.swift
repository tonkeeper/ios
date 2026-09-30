import CryptoKit
import Foundation
import TKKeychain
import TKLogging

/// Keychain home of the per-wallet app key and of the credential minted from it. Device-only and
/// never migrated: both are bound to the device this install registered.
///
/// Stateless, so the owning actor is the only serialization this needs.
final class WalletAuthKeychainStore: @unchecked Sendable {
    /// The access token itself stays out of the Keychain — `DeviceTokenStore` keeps it in memory on
    /// purpose — so the record carries only enough to tell whether the token still signs it.
    struct TokenRecord: Codable {
        let accessTokenFingerprint: String
        let token: String
    }

    private enum Item: String {
        case appKey
        case token
    }

    private let keychainVault: TKKeychainVault

    init(keychainVault: TKKeychainVault) {
        self.keychainVault = keychainVault
    }

    /// `nil` for a wallet the Keychain conclusively has no key for; throws when it could not be read
    /// at all, which the caller has to retry rather than remember.
    func loadAppKey(walletId: String) throws -> Data? {
        do {
            // Explicit type: an inferred `Data?` would pick the `Codable` overload and decode.
            let appKey: Data = try keychainVault.get(query: query(walletId: walletId, item: .appKey))
            return appKey
        } catch TKKeychainVaultError.unexpectedData, TKKeychainError.noItem {
            return nil
        }
    }

    func saveAppKey(_ appKey: Data, walletId: String) {
        do {
            try keychainVault.set(appKey, query: query(walletId: walletId, item: .appKey))
        } catch {
            Log.w("🪵 WalletAuth: save app key failed", error: error)
        }
    }

    /// A miss costs one signature, so every failure is the same answer here: no record.
    func loadToken(walletId: String) -> TokenRecord? {
        do {
            let record: TokenRecord = try keychainVault.get(query: query(walletId: walletId, item: .token))
            return record
        } catch TKKeychainVaultError.unexpectedData, TKKeychainError.noItem {
            return nil
        } catch {
            Log.w("🪵 WalletAuth: load token failed", error: error)
            return nil
        }
    }

    func saveToken(_ record: TokenRecord, walletId: String) {
        do {
            try keychainVault.set(record, query: query(walletId: walletId, item: .token))
        } catch {
            Log.w("🪵 WalletAuth: save token failed", error: error)
        }
    }

    /// Drops the minted credential but keeps the app key, so the next request signs a fresh one
    /// without a passcode.
    func deleteToken(walletId: String) {
        try? keychainVault.delete(query(walletId: walletId, item: .token))
    }

    func delete(walletId: String) {
        try? keychainVault.delete(query(walletId: walletId, item: .appKey))
        try? keychainVault.delete(query(walletId: walletId, item: .token))
    }

    /// Omitting the account matches every item under the service, so one delete covers wallets this
    /// install no longer knows about.
    func deleteAll() {
        try? keychainVault.delete(
            TKKeychainQuery(
                item: .genericPassword(service: .service, account: nil),
                accessGroup: nil,
                biometry: .none,
                accessible: .whenUnlockedThisDeviceOnly
            )
        )
    }

    static func fingerprint(accessToken: String) -> String {
        Data(SHA256.hash(data: Data(accessToken.utf8))).hexString()
    }

    private func query(walletId: String, item: Item) -> TKKeychainQuery {
        TKKeychainQuery(
            item: .genericPassword(service: .service, account: "\(walletId)/\(item.rawValue)"),
            accessGroup: nil,
            biometry: .none,
            accessible: .whenUnlockedThisDeviceOnly
        )
    }
}

private extension String {
    static let service = "MultichainWalletAuth"
}
