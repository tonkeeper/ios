import Foundation
import KeeperCoreComponents
import TKLogging

struct WalletConnectStoredPairingSource: Codable, Equatable {
    var source: DappConnectionSource
    var expiresAt: Date

    init(
        source: DappConnectionSource,
        expiresAt: Date
    ) {
        self.source = source
        self.expiresAt = expiresAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.source = container.decodeDappConnectionSourceIfPresent(forKey: .source) ?? .deeplink
        self.expiresAt = try container.decode(Date.self, forKey: .expiresAt)
    }
}

typealias WalletConnectPairingTopic = String

struct WalletConnectStoredPairingSources: Codable {
    var sources: [WalletConnectPairingTopic: WalletConnectStoredPairingSource]
}

enum WalletConnectPairingSourceStoreError: Error, Equatable {
    case saveFailed(message: String)
}

struct WalletConnectPairingSourceStore {
    private let vault: FileSystemVault<WalletConnectStoredPairingSources, String>
    private let key = "wallet_connect_pairing_sources"

    init(
        vault: FileSystemVault<WalletConnectStoredPairingSources, String>
    ) {
        self.vault = vault
    }

    func load() -> [WalletConnectPairingTopic: WalletConnectStoredPairingSource] {
        do {
            return try vault.loadItem(key: key).sources
        } catch let error as FileSystemVault<WalletConnectStoredPairingSources, String>.LoadError {
            switch error {
            case .noItem:
                return [:]
            default:
                Log.w("WalletConnect: failed to load stored pairing sources", error: error)
                return [:]
            }
        } catch {
            Log.w("WalletConnect: failed to load stored pairing sources", error: error)
            return [:]
        }
    }

    func save(
        _ sources: [WalletConnectPairingTopic: WalletConnectStoredPairingSource]
    ) throws(WalletConnectPairingSourceStoreError) {
        do {
            try vault.saveItem(
                WalletConnectStoredPairingSources(sources: sources),
                key: key
            )
        } catch {
            throw .saveFailed(message: error.logDescription)
        }
    }
}
