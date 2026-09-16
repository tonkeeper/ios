import ChainKit
import Foundation
import TKKeychain
import TKLogging

/// Keychain-backed `SecureKeyStore` for the ChainKit Lighter engine, scoped to one
/// wallet and one environment so testnet and mainnet credentials never mix.
final class LighterCredentialsStore: NSObject, SecureKeyStore {
    private struct StoredAccount: Codable {
        let accountIndex: Int64
        let apiKeyIndex: Int32
    }

    private let keychainVault: TKKeychainVault
    private let walletId: String
    private let environment: String

    init(keychainVault: TKKeychainVault, walletId: String, environment: String) {
        self.keychainVault = keychainVault
        self.walletId = walletId
        self.environment = environment
    }

    func loadL2PrivateKey(completionHandler: @escaping (KotlinByteArray?, Error?) -> Void) {
        do {
            let data: Data = try keychainVault.get(query: query(item: .l2PrivateKey))
            completionHandler(data.asKotlinByteArray, nil)
        } catch TKKeychainVaultError.unexpectedData, TKKeychainError.noItem {
            // No stored key yet (first activation) — absent, not a failure.
            completionHandler(nil, nil)
        } catch {
            Log.w("🪵 Lighter: loadL2PrivateKey failed", error: error)
            completionHandler(nil, error)
        }
    }

    func saveL2PrivateKey(key: KotlinByteArray, completionHandler: @escaping (Error?) -> Void) {
        do {
            try keychainVault.set(key.asData, query: query(item: .l2PrivateKey))
            completionHandler(nil)
        } catch {
            Log.w("🪵 Lighter: saveL2PrivateKey failed", error: error)
            completionHandler(error)
        }
    }

    func loadAccount(completionHandler: @escaping (StoredLighterAccount?, Error?) -> Void) {
        do {
            let stored: StoredAccount = try keychainVault.get(query: query(item: .account))
            completionHandler(
                StoredLighterAccount(accountIndex: stored.accountIndex, apiKeyIndex: stored.apiKeyIndex),
                nil
            )
        } catch TKKeychainVaultError.unexpectedData, TKKeychainError.noItem {
            // No stored account yet — absent, not a failure.
            completionHandler(nil, nil)
        } catch {
            Log.w("🪵 Lighter: loadAccount failed", error: error)
            completionHandler(nil, error)
        }
    }

    func saveAccount(account: StoredLighterAccount, completionHandler: @escaping (Error?) -> Void) {
        do {
            try keychainVault.set(
                StoredAccount(accountIndex: account.accountIndex, apiKeyIndex: account.apiKeyIndex),
                query: query(item: .account)
            )
            completionHandler(nil)
        } catch {
            Log.w("🪵 Lighter: saveAccount failed", error: error)
            completionHandler(error)
        }
    }

    func clear(completionHandler: @escaping (Error?) -> Void) {
        clear()
        completionHandler(nil)
    }

    func clear() {
        try? keychainVault.delete(query(item: .l2PrivateKey))
        try? keychainVault.delete(query(item: .account))
        try? keychainVault.delete(query(item: .l1Address))
    }

    /// The wallet's L1 address is public data; cached so the account probe
    /// works even when the wallet has no multichain enrichment.
    func saveL1Address(_ address: String) {
        do {
            try keychainVault.set(address, query: query(item: .l1Address))
        } catch {
            Log.w("🪵 Lighter: saveL1Address failed", error: error)
        }
    }

    func loadL1Address() -> String? {
        try? keychainVault.get(query: query(item: .l1Address))
    }

    private enum Item: String {
        case l2PrivateKey = "l2key"
        case account
        case l1Address = "l1addr"
    }

    private func query(item: Item) -> TKKeychainQuery {
        TKKeychainQuery(
            item: .genericPassword(
                service: "LighterCredentials",
                account: "\(walletId)/\(environment)/\(item.rawValue)"
            ),
            accessGroup: nil,
            biometry: .none,
            accessible: .whenUnlockedThisDeviceOnly
        )
    }
}
