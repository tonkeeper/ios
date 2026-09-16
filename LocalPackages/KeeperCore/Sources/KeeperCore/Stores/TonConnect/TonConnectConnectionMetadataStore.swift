import Foundation
import KeeperCoreComponents
import TKLogging

public struct TonConnectConnectionMetadata: Codable, Equatable, Sendable {
    public let sourceState: DappConnectionSourceState

    public init(
        source: DappConnectionSource,
        createdAt: Date
    ) {
        self.sourceState = .known(
            DappConnectionExtraInfo(
                source: source,
                createdAt: createdAt
            )
        )
    }

    public init(sourceState: DappConnectionSourceState) {
        self.sourceState = sourceState
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sourceState = DappConnectionSourceState(
            source: container.decodeDappConnectionSourceIfPresent(forKey: .source),
            createdAt: try? container.decodeIfPresent(Date.self, forKey: .createdAt)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        guard let extraInfo = sourceState.extraInfo else {
            return
        }
        try container.encode(extraInfo.source, forKey: .source)
        try container.encode(extraInfo.createdAt, forKey: .createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case source
        case createdAt
    }
}

struct TonConnectStoredConnectionMetadata: Codable {
    var metadata: [String: TonConnectConnectionMetadata]
}

public final class TonConnectConnectionMetadataStore {
    private let vault: FileSystemVault<TonConnectStoredConnectionMetadata, String>
    private let now: @Sendable () -> Date
    private let lock = NSLock()
    private let key = "ton_connect_connection_metadata"

    private var pendingConnectionSourcesByClientId = [String: DappConnectionSource]()
    private var pendingConnectionSourcesByManifestHost = [String: DappConnectionSource]()

    init(
        vault: FileSystemVault<TonConnectStoredConnectionMetadata, String>,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.vault = vault
        self.now = now
    }

    public func setPendingConnectionSource(
        _ source: DappConnectionSource,
        clientId: String,
        manifestURL: URL?
    ) {
        lock.lock()
        defer { lock.unlock() }

        pendingConnectionSourcesByClientId[clientId] = source
        if let host = manifestURL?.host?.lowercased(), !host.isEmpty {
            pendingConnectionSourcesByManifestHost[host] = source
        }
    }

    public func consumePendingConnectionSource(
        clientId: String,
        manifestURL: URL?
    ) -> DappConnectionSource? {
        lock.lock()
        defer { lock.unlock() }

        let host = manifestURL?.host?.lowercased()
        if let source = pendingConnectionSourcesByClientId.removeValue(forKey: clientId) {
            if let host, !host.isEmpty {
                pendingConnectionSourcesByManifestHost.removeValue(forKey: host)
            }
            return source
        }

        guard let host, !host.isEmpty else {
            return nil
        }
        return pendingConnectionSourcesByManifestHost.removeValue(forKey: host)
    }

    public func recordConnection(
        wallet: Wallet,
        clientId: String,
        source: DappConnectionSource
    ) {
        recordConnection(
            wallet: wallet,
            clientId: clientId,
            metadata: TonConnectConnectionMetadata(
                source: source,
                createdAt: now()
            )
        )
    }

    public func recordConnection(
        wallet: Wallet,
        clientId: String,
        metadata: TonConnectConnectionMetadata
    ) {
        lock.lock()
        defer { lock.unlock() }

        var stored = loadStoredMetadata()
        stored[metadataKey(wallet: wallet, clientId: clientId)] = metadata
        saveStoredMetadata(stored)
    }

    public func metadata(
        wallet: Wallet,
        clientId: String
    ) -> TonConnectConnectionMetadata? {
        lock.lock()
        defer { lock.unlock() }

        return loadStoredMetadata()[metadataKey(wallet: wallet, clientId: clientId)]
    }

    public func metadata(wallet: Wallet) -> [String: TonConnectConnectionMetadata] {
        lock.lock()
        defer { lock.unlock() }

        let keyPrefix = metadataKeyPrefix(wallet: wallet)
        return loadStoredMetadata().reduce(into: [:]) { result, pair in
            guard pair.key.hasPrefix(keyPrefix) else { return }
            let clientId = String(pair.key.dropFirst(keyPrefix.count))
            result[clientId] = pair.value
        }
    }

    public func deleteConnection(
        wallet: Wallet,
        clientId: String
    ) {
        lock.lock()
        defer { lock.unlock() }

        var stored = loadStoredMetadata()
        stored.removeValue(forKey: metadataKey(wallet: wallet, clientId: clientId))
        saveStoredMetadata(stored)
    }
}

private extension TonConnectConnectionMetadataStore {
    func metadataKey(wallet: Wallet, clientId: String) -> String {
        metadataKeyPrefix(wallet: wallet) + clientId
    }

    func metadataKeyPrefix(wallet: Wallet) -> String {
        "\(wallet.id):"
    }

    func loadStoredMetadata() -> [String: TonConnectConnectionMetadata] {
        do {
            return try vault.loadItem(key: key).metadata
        } catch let error as FileSystemVault<TonConnectStoredConnectionMetadata, String>.LoadError {
            switch error {
            case .noItem:
                return [:]
            default:
                Log.w("TonConnect: failed to load connection metadata: \(error)")
                return [:]
            }
        } catch {
            Log.w("TonConnect: failed to load connection metadata: \(error)")
            return [:]
        }
    }

    func saveStoredMetadata(_ metadata: [String: TonConnectConnectionMetadata]) {
        do {
            try vault.saveItem(
                TonConnectStoredConnectionMetadata(metadata: metadata),
                key: key
            )
        } catch {
            Log.w("TonConnect: failed to save connection metadata: \(error)")
        }
    }
}
