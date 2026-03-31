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

    init(tonConnectService: TonConnectService) {
        self.tonConnectService = tonConnectService
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
        guard let app = try? connectedApps(forWallet: wallet).apps.first(where: {
            $0.manifest.url.host == appUrl?.host
        }) else {
            return
        }
        try? tonConnectService.disconnectApp(app, wallet: wallet)
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

        try? tonConnectService.disconnectApp(idx, wallet: wallet)
        notifyObservers(event: .didUpdateApps)
        notifyObservers(event: .didDisconnect(app: apps[idx], wallet: wallet))
    }

    public func disconnect(wallet: Wallet, appClientId: String) throws {
        let apps = try? connectedApps(forWallet: wallet).apps
        guard let apps, let idx = apps.firstIndex(where: { $0.clientId == appClientId }) else {
            return
        }

        try? tonConnectService.disconnectApp(idx, wallet: wallet)
        notifyObservers(event: .didUpdateApps)
        notifyObservers(event: .didDisconnect(app: apps[idx], wallet: wallet))
    }

    public func connectedApps(forWallet wallet: Wallet) throws -> TonConnectApps {
        try tonConnectService.getConnectedApps(forWallet: wallet)
    }

    public func deleteConnectedApp(wallet: Wallet, app: TonConnectApp) {
        try? tonConnectService.disconnectApp(app, wallet: wallet)
        notifyObservers(event: .didDisconnect(app: app, wallet: wallet))
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
    func removeNilObservers() {
        observers = observers.filter { $0.observer != nil }
    }
}
