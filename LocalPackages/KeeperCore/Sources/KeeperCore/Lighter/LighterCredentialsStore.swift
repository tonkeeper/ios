import Foundation
import TKKeychain
import TKLogging

struct PerpsStoredAccount {
    let accountIndex: Int64
    let apiKeyIndex: Int32
}

/// Keychain-backed store for the perps trading key, scoped to one wallet and one
/// environment so testnet and mainnet credentials never mix.
final class LighterCredentialsStore {
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

    func loadL2PrivateKey() throws -> Data? {
        do {
            return try keychainVault.get(query: query(item: .l2PrivateKey))
        } catch TKKeychainVaultError.unexpectedData, TKKeychainError.noItem {
            // No stored key yet (first activation) — absent, not a failure.
            return nil
        } catch {
            Log.w("🪵 Lighter: loadL2PrivateKey failed", error: error)
            throw error
        }
    }

    func saveL2PrivateKey(_ key: Data) throws {
        do {
            try keychainVault.set(key, query: query(item: .l2PrivateKey))
        } catch {
            Log.w("🪵 Lighter: saveL2PrivateKey failed", error: error)
            throw error
        }
    }

    func loadAccount() throws -> PerpsStoredAccount? {
        do {
            let stored: StoredAccount = try keychainVault.get(query: query(item: .account))
            return PerpsStoredAccount(accountIndex: stored.accountIndex, apiKeyIndex: stored.apiKeyIndex)
        } catch TKKeychainVaultError.unexpectedData, TKKeychainError.noItem {
            // No stored account yet — absent, not a failure.
            return nil
        } catch {
            Log.w("🪵 Lighter: loadAccount failed", error: error)
            throw error
        }
    }

    func saveAccount(_ account: PerpsStoredAccount) throws {
        do {
            try keychainVault.set(
                StoredAccount(accountIndex: account.accountIndex, apiKeyIndex: account.apiKeyIndex),
                query: query(item: .account)
            )
        } catch {
            Log.w("🪵 Lighter: saveAccount failed", error: error)
            throw error
        }
    }

    func clear() {
        try? keychainVault.delete(query(item: .l2PrivateKey))
        try? keychainVault.delete(query(item: .account))
    }

    private enum Item: String {
        case l2PrivateKey = "l2key"
        case account
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
