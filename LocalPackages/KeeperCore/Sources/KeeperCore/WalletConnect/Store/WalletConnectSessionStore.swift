import Foundation
import KeeperCoreComponents
import TKLogging

struct WalletConnectStoredSession: Codable, Equatable {
    var walletId: String
    var sourceState: DappConnectionSourceState

    var source: DappConnectionSource? {
        sourceState.extraInfo?.source
    }

    var createdAt: Date? {
        sourceState.extraInfo?.createdAt
    }

    init(
        walletId: String,
        source: DappConnectionSource,
        createdAt: Date
    ) {
        self.walletId = walletId
        self.sourceState = .known(
            DappConnectionExtraInfo(
                source: source,
                createdAt: createdAt
            )
        )
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.walletId = try container.decode(String.self, forKey: .walletId)
        self.sourceState = DappConnectionSourceState(
            source: container.decodeDappConnectionSourceIfPresent(forKey: .source),
            createdAt: try? container.decodeIfPresent(Date.self, forKey: .createdAt)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(walletId, forKey: .walletId)
        guard let extraInfo = sourceState.extraInfo else {
            return
        }
        try container.encode(extraInfo.source, forKey: .source)
        try container.encode(extraInfo.createdAt, forKey: .createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case walletId
        case source
        case createdAt
    }
}

typealias WalletConnectSessionTopic = String

struct WalletConnectStoredSessions: Codable {
    var sessions: [WalletConnectSessionTopic: WalletConnectStoredSession]
}

enum WalletConnectSessionStoreError: Error, Equatable {
    case saveFailed(message: String)
}

struct WalletConnectSessionStore {
    private let vault: FileSystemVault<WalletConnectStoredSessions, String>
    private let key = "wallet_connect_sessions"

    init(
        vault: FileSystemVault<WalletConnectStoredSessions, String>
    ) {
        self.vault = vault
    }

    func load() -> [WalletConnectSessionTopic: WalletConnectStoredSession] {
        do {
            return try vault.loadItem(key: key).sessions
        } catch let error as FileSystemVault<WalletConnectStoredSessions, String>.LoadError {
            switch error {
            case .noItem:
                return [:]
            default:
                Log.w("WalletConnect: failed to load stored sessions", error: error)
                return [:]
            }
        } catch {
            Log.w("WalletConnect: failed to load stored sessions", error: error)
            return [:]
        }
    }

    func save(
        _ sessions: [WalletConnectSessionTopic: WalletConnectStoredSession]
    ) throws(WalletConnectSessionStoreError) {
        do {
            try vault.saveItem(
                WalletConnectStoredSessions(sessions: sessions),
                key: key
            )
        } catch {
            throw .saveFailed(message: error.logDescription)
        }
    }
}
