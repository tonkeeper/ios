import Foundation
import TonSwift

public enum TonConnectAppsStoreEvent {
    case didUpdateApps
    case didDisconnect(app: TonConnectApp, wallet: Wallet)
}

public protocol TonConnectAppsStoreObserver: AnyObject {
    func didGetTonConnectAppsStoreEvent(_ event: TonConnectAppsStoreEvent)
}

public final class TonConnectAppsStore {
    public enum FetchResult {
        case response(Data)
        case error(TonConnect.FetchEventError.ErrorCode)
    }

    public enum ConnectResult {
        case response(Data)
        case error(TonConnect.ConnectEventError.Error)
    }

    public enum SendResult {
        case response(Data)
        case error(TonConnect.SendResponseError.ErrorCode)
    }

    let tonConnectService: TonConnectService
    private let connectionMetadataStore: TonConnectConnectionMetadataStore

    init(
        tonConnectService: TonConnectService,
        connectionMetadataStore: TonConnectConnectionMetadataStore
    ) {
        self.tonConnectService = tonConnectService
        self.connectionMetadataStore = connectionMetadataStore
    }

    public func connect(
        wallet: Wallet,
        parameters: TonConnectParameters,
        manifest: TonConnectManifest,
        signTonProofHandler: @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply,
        keeperVersion: String
    ) async throws {
        let connectEventSuccessResponse = try await tonConnectService.buildConnectEventSuccessResponse(
            wallet: wallet,
            parameters: parameters,
            manifest: manifest,
            signTonProofHandler: signTonProofHandler,
            keeperVersion: keeperVersion
        )
        let sessionCrypto = try TonConnectSessionCrypto()
        let encrypted = try tonConnectService.encryptSuccessResponse(
            connectEventSuccessResponse,
            parameters: parameters,
            sessionCrypto: sessionCrypto
        )
        try await tonConnectService.confirmConnectionRequest(
            body: encrypted,
            sessionCrypto: sessionCrypto,
            parameters: parameters
        )
        try tonConnectService.storeConnectedApp(
            wallet: wallet,
            sessionCrypto: sessionCrypto,
            parameters: parameters,
            manifest: manifest,
            connectionType: .remote
        )
        recordConnectionMetadata(
            wallet: wallet,
            clientId: parameters.clientId,
            source: parameters.source,
            notifyObservers: false
        )
        await MainActor.run {
            notifyObservers(event: .didUpdateApps)
        }
    }

    public func connectBridgeDapp(
        wallet: Wallet,
        parameters: TonConnectParameters,
        manifest: TonConnectManifest,
        signTonProofHandler: @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply,
        keeperVersion: String
    ) async -> ConnectResult {
        do {
            let connectEventSuccessResponse = try await tonConnectService.buildConnectEventSuccessResponse(
                wallet: wallet,
                parameters: parameters,
                manifest: manifest,
                signTonProofHandler: signTonProofHandler,
                keeperVersion: keeperVersion
            )
            let response = try JSONEncoder().encode(connectEventSuccessResponse)
            let sessionCrypto = try TonConnectSessionCrypto()
            try tonConnectService.storeConnectedApp(
                wallet: wallet,
                sessionCrypto: sessionCrypto,
                parameters: parameters,
                manifest: manifest,
                connectionType: .bridge
            )
            recordConnectionMetadata(
                wallet: wallet,
                clientId: parameters.clientId,
                source: parameters.source,
                notifyObservers: false
            )
            notifyObservers(event: .didUpdateApps)
            return .response(response)
        } catch {
            return .error(.unknownError)
        }
    }

    public func reconnectBridgeDapp(wallet: Wallet, appUrl: URL?, keeperVersion: String) -> ConnectResult {
        guard let app = try? connectedApps(forWallet: wallet).apps.first(where: {
            $0.manifest.url.host == appUrl?.host && $0.connectionType == .bridge
        }) else {
            return .error(.unknownApp)
        }
        do {
            let response = try tonConnectService.buildReconnectConnectEventSuccessResponse(
                wallet: wallet,
                manifest: app.manifest,
                keeperVersion: keeperVersion
            )
            let responseData = try JSONEncoder().encode(response)
            return .response(responseData)
        } catch {
            return .error(.unknownError)
        }
    }

    public func disconnect(wallet: Wallet, appUrl: URL?) throws {
        let apps = try? connectedApps(forWallet: wallet).apps
        guard let apps, let app = apps.first(where: {
            $0.manifest.url.host == appUrl?.host
        }) else {
            return
        }

        try? tonConnectService.disconnectApp(app, wallet: wallet)
        deleteConnectionMetadata(
            wallet: wallet,
            apps: apps.filter { $0.manifest.host == app.manifest.host }
        )
        notifyObservers(event: .didUpdateApps)
        notifyObservers(event: .didDisconnect(app: app, wallet: wallet))
    }

    public func disconnectBridge(wallet: Wallet, appUrl: URL?) throws {
        let apps = try? connectedApps(forWallet: wallet).apps
        guard let apps, let idx = apps.firstIndex(where: {
            $0.manifest.url.host == appUrl?.host && $0.connectionType == .bridge
        }) else {
            return
        }

        let app = apps[idx]
        try? tonConnectService.disconnectApp(idx, wallet: wallet)
        connectionMetadataStore.deleteConnection(wallet: wallet, clientId: app.clientId)
        notifyObservers(event: .didUpdateApps)
        notifyObservers(event: .didDisconnect(app: app, wallet: wallet))
    }

    public func disconnect(wallet: Wallet, appClientId: String) throws {
        let apps = try? connectedApps(forWallet: wallet).apps
        guard let apps, let idx = apps.firstIndex(where: { $0.clientId == appClientId }) else {
            return
        }

        let app = apps[idx]
        try? tonConnectService.disconnectApp(idx, wallet: wallet)
        connectionMetadataStore.deleteConnection(wallet: wallet, clientId: app.clientId)
        notifyObservers(event: .didUpdateApps)
        notifyObservers(event: .didDisconnect(app: app, wallet: wallet))
    }

    public func connectedApps(forWallet wallet: Wallet) throws -> TonConnectApps {
        try tonConnectService.getConnectedApps(forWallet: wallet)
    }

    func recordConnectionMetadata(
        wallet: Wallet,
        clientId: String,
        source: DappConnectionSource,
        notifyObservers: Bool
    ) {
        connectionMetadataStore.recordConnection(
            wallet: wallet,
            clientId: clientId,
            source: source
        )
        if notifyObservers {
            self.notifyObservers(event: .didUpdateApps)
        }
    }

    @discardableResult
    func recordConnectionMetadata(
        wallet: Wallet,
        clientId: String,
        manifestURL: URL?,
        fallbackSource: DappConnectionSource = .deeplink,
        notifyObservers: Bool
    ) -> DappConnectionSource {
        let source = consumePendingConnectionSource(
            clientId: clientId,
            manifestURL: manifestURL
        ) ?? fallbackSource
        recordConnectionMetadata(
            wallet: wallet,
            clientId: clientId,
            source: source,
            notifyObservers: notifyObservers
        )
        return source
    }

    public func connectionMetadata(
        wallet: Wallet,
        clientId: String
    ) -> TonConnectConnectionMetadata? {
        connectionMetadataStore.metadata(
            wallet: wallet,
            clientId: clientId
        )
    }

    public func deleteConnectedApp(wallet: Wallet, app: TonConnectApp) {
        let removedApps = (try? connectedApps(forWallet: wallet).apps.filter {
            $0.manifest.host == app.manifest.host
        }) ?? [app]

        try? tonConnectService.disconnectApp(app, wallet: wallet)
        deleteConnectionMetadata(wallet: wallet, apps: removedApps)
        notifyObservers(event: .didDisconnect(app: app, wallet: wallet))
    }

    public func deleteConnectedAppSession(wallet: Wallet, app: TonConnectApp) {
        try? tonConnectService.disconnectApp(app.clientId, wallet: wallet)
        connectionMetadataStore.deleteConnection(wallet: wallet, clientId: app.clientId)
        notifyObservers(event: .didDisconnect(app: app, wallet: wallet))
    }

    public func setPendingConnectionSource(
        _ source: DappConnectionSource,
        clientId: String,
        manifestURL: URL?
    ) {
        connectionMetadataStore.setPendingConnectionSource(
            source,
            clientId: clientId,
            manifestURL: manifestURL
        )
    }

    public func consumePendingConnectionSource(
        clientId: String,
        manifestURL: URL?
    ) -> DappConnectionSource? {
        connectionMetadataStore.consumePendingConnectionSource(
            clientId: clientId,
            manifestURL: manifestURL
        )
    }

    public func getLastEventId() -> String? {
        try? tonConnectService.getLastEventId()
    }

    public func saveLastEventId(_ lastEventId: String?) {
        guard let lastEventId else { return }
        try? tonConnectService.saveLastEventId(lastEventId)
    }

    private var observers = [TonConnectAppsStoreObserverWrapper]()

    struct TonConnectAppsStoreObserverWrapper {
        weak var observer: TonConnectAppsStoreObserver?
    }

    public func addObserver(_ observer: TonConnectAppsStoreObserver) {
        removeNilObservers()
        observers = observers + CollectionOfOne(TonConnectAppsStoreObserverWrapper(observer: observer))
    }

    func notifyObservers(event: TonConnectAppsStoreEvent) {
        observers.forEach { $0.observer?.didGetTonConnectAppsStoreEvent(event) }
    }
}

private extension TonConnectAppsStore {
    func deleteConnectionMetadata(wallet: Wallet, apps: [TonConnectApp]) {
        for app in apps {
            connectionMetadataStore.deleteConnection(
                wallet: wallet,
                clientId: app.clientId
            )
        }
    }

    func removeNilObservers() {
        observers = observers.filter { $0.observer != nil }
    }
}
