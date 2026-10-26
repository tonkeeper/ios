import ChainKit
import Foundation
import TKKeychain
import TKLogging

struct PerpsStoredAccount {
    let accountIndex: Int64
    let apiKeyIndex: Int32
    let keyDerivationIndex: Int64

    init(accountIndex: Int64, apiKeyIndex: Int32, keyDerivationIndex: Int64? = nil) {
        self.accountIndex = accountIndex
        self.apiKeyIndex = apiKeyIndex
        self.keyDerivationIndex = keyDerivationIndex ?? accountIndex
    }
}

/// Keychain-backed store for the perps trading key, scoped to one wallet and one
/// environment so testnet and mainnet credentials never mix.
final class LighterCredentialsStore {
    private struct StoredAccount: Codable {
        let accountIndex: Int64
        let apiKeyIndex: Int32
        let keyDerivationIndex: Int64?
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
            let key: Data = try keychainVault.get(query: query(item: .l2PrivateKey))
            return key
        } catch TKKeychainVaultError.unexpectedData, TKKeychainError.noItem {
            // No stored key yet (first activation) — absent, not a failure.
            return nil
        } catch {
            Log.perps.w("Lighter: loadL2PrivateKey failed", error: error)
            throw error
        }
    }

    func saveL2PrivateKey(_ key: Data) throws {
        do {
            try keychainVault.set(key, query: query(item: .l2PrivateKey))
        } catch {
            Log.perps.w("Lighter: saveL2PrivateKey failed", error: error)
            throw error
        }
    }

    func keepL2PrivateKey(_ key: Data) throws {
        try keychainVault.setIfAbsent(key, query: query(item: .l2PrivateKey))
    }

    func keepTradingKey(cryptoWallet: CryptoWallet) async throws {
        guard try loadL2PrivateKey() == nil else { return }
        let mediator = CompositePerpetualMediator().getAccountMediator(chain: .lighter)
        let key: KotlinByteArray = try await bridgeKotlin { completion in
            mediator.keySource(wallet: cryptoWallet).deriveTradingKey(completionHandler: completion)
        }
        defer { key.fillZeros() }
        try keepL2PrivateKey(key.asData)
    }

    func loadAccount() throws -> PerpsStoredAccount? {
        do {
            let stored: StoredAccount = try keychainVault.get(query: query(item: .account))
            return PerpsStoredAccount(
                accountIndex: stored.accountIndex,
                apiKeyIndex: stored.apiKeyIndex,
                keyDerivationIndex: stored.keyDerivationIndex
            )
        } catch TKKeychainVaultError.unexpectedData, TKKeychainError.noItem {
            // No stored account yet — absent, not a failure.
            return nil
        } catch {
            Log.perps.w("Lighter: loadAccount failed", error: error)
            throw error
        }
    }

    func saveAccount(_ account: PerpsStoredAccount) throws {
        do {
            try keychainVault.set(
                StoredAccount(
                    accountIndex: account.accountIndex,
                    apiKeyIndex: account.apiKeyIndex,
                    keyDerivationIndex: account.keyDerivationIndex
                ),
                query: query(item: .account)
            )
        } catch {
            Log.perps.w("Lighter: saveAccount failed", error: error)
            throw error
        }
    }

    func loadIntegratorApproval() throws -> PerpsIntegratorApproval? {
        do {
            let approval: PerpsIntegratorApproval = try keychainVault.get(query: query(item: .integratorApproval))
            return approval
        } catch TKKeychainVaultError.unexpectedData, TKKeychainVaultError.decodingError, TKKeychainError.noItem {
            return nil
        } catch {
            Log.perps.w("Lighter: loadIntegratorApproval failed", error: error)
            throw error
        }
    }

    func saveIntegratorApproval(_ approval: PerpsIntegratorApproval) throws {
        do {
            try keychainVault.set(approval, query: query(item: .integratorApproval))
        } catch {
            Log.perps.w("Lighter: saveIntegratorApproval failed", error: error)
            throw error
        }
    }

    func clearIntegratorApproval() {
        try? keychainVault.delete(query(item: .integratorApproval))
    }

    func clear() {
        try? keychainVault.delete(query(item: .l2PrivateKey))
        try? keychainVault.delete(query(item: .account))
        clearIntegratorApproval()
    }

    private enum Item: String {
        case l2PrivateKey = "l2key"
        case account
        case integratorApproval
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
