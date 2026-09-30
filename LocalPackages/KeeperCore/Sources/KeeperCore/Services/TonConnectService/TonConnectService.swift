import BigInt
import Foundation
import KeeperCoreComponents
import TonConnectAPI
import TonSwift

public enum TonConnectManifestError: Swift.Error {
    case incorrectURL
    case loadFailed(error: Swift.Error)
    case invalidManifest
}

enum TonConnectServiceError: Swift.Error {
    case incorrectUrl
    case manifestLoadFailed
    case unsupportedWalletKind(walletKind: WalletKind)
    case incorrectClientId
}

public protocol TonConnectService {
    func loadAppManifest(parameters: TonConnectParameters) async -> Result<TonConnectManifest, TonConnectManifestError>
    func buildConnectEventSuccessResponse(
        wallet: Wallet,
        parameters: TonConnectParameters,
        manifest: TonConnectManifest, signTonProofHandler: @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply,
        keeperVersion: String
    ) async throws -> TonConnect.ConnectEventSuccess
    func encryptSuccessResponse(
        _ successResponse: TonConnect.ConnectEventSuccess,
        parameters: TonConnectParameters,
        sessionCrypto: TonConnectSessionCrypto
    ) throws -> String
    func buildReconnectConnectEventSuccessResponse(
        wallet: Wallet,
        manifest: TonConnectManifest,
        keeperVersion: String
    ) throws -> TonConnect.ConnectEventSuccess
    func storeConnectedApp(
        wallet: Wallet,
        sessionCrypto: TonConnectSessionCrypto,
        parameters: TonConnectParameters,
        manifest: TonConnectManifest,
        connectionType: TonConnectApp.ConnectionType
    ) throws
    func confirmConnectionRequest(
        body: String,
        sessionCrypto: TonConnectSessionCrypto,
        parameters: TonConnectParameters
    ) async throws
    func getConnectedApps(forWallet wallet: Wallet) throws -> TonConnectApps
    func disconnectApp(_ app: TonConnectApp, wallet: Wallet) throws
    func disconnectApp(_ clientId: String, wallet: Wallet) throws
    func disconnectApp(_ idx: Int, wallet: Wallet) throws

    func cancelRequest(
        appRequest: TonConnect.SendTransactionRequest,
        app: TonConnectApp
    ) async throws

    func confirmRequest(
        boc: String,
        appRequest: TonConnect.SendTransactionRequest,
        app: TonConnectApp
    ) async throws

    func cancelSignRequest(
        appRequest: TonConnect.SignDataRequest,
        app: TonConnectApp
    ) async throws

    func confirmSignRequest(
        signed: SignedDataResult,
        appRequest: TonConnect.SignDataRequest,
        app: TonConnectApp
    ) async throws

    func confirmDisconnectRequest(
        appRequest: TonConnect.DisconnectRequest,
        app: TonConnectApp
    ) async throws

    func getLastEventId() throws -> String
    func saveLastEventId(_ lastEventId: String) throws
    func loadManifest(url: URL) async throws -> TonConnectManifest
}

final class TonConnectServiceImplementation: TonConnectService {
    private static let tonConnectAppsLock = NSLock()

    private let manifestLoader: TonConnectManifestLoader
    private let tonConnectBridgeAPIClientProvider: TonConnectBridgeAPIClientProvider
    private let tonConnectAppsVault: TonConnectAppsVault
    private let tonConnectRepository: TonConnectRepository
    private let walletBalanceRepository: WalletBalanceRepository
    private let sendService: SendService

    init(
        urlSession: URLSession,
        tonConnectBridgeAPIClientProvider: TonConnectBridgeAPIClientProvider,
        tonConnectAppsVault: TonConnectAppsVault,
        tonConnectRepository: TonConnectRepository,
        walletBalanceRepository: WalletBalanceRepository,
        sendService: SendService
    ) {
        self.manifestLoader = TonConnectManifestLoader(urlSession: urlSession)
        self.tonConnectBridgeAPIClientProvider = tonConnectBridgeAPIClientProvider
        self.tonConnectAppsVault = tonConnectAppsVault
        self.tonConnectRepository = tonConnectRepository
        self.walletBalanceRepository = walletBalanceRepository
        self.sendService = sendService
    }

    func loadAppManifest(parameters: TonConnectParameters) async -> Result<TonConnectManifest, TonConnectManifestError> {
        do {
            let manifest = try await loadManifest(url: parameters.requestPayload.manifestUrl)
            return .success(manifest)
        } catch let error as TonConnectManifestError {
            return .failure(error)
        } catch {
            return .failure(TonConnectManifestError.loadFailed(error: error))
        }
    }

    func buildReconnectConnectEventSuccessResponse(
        wallet: Wallet,
        manifest: TonConnectManifest,
        keeperVersion: String
    ) throws -> TonConnect.ConnectEventSuccess {
        guard wallet.isTonconnectAvailable else {
            throw
                TonConnectServiceError.unsupportedWalletKind(
                    walletKind: wallet.identity.kind
                )
        }
        return try TonConnectResponseBuilder.buildReconnectConnectEventSuccessResponse(
            wallet: wallet,
            keeperVersion: keeperVersion,
            manifest: manifest
        )
    }

    func buildConnectEventSuccessResponse(
        wallet: Wallet,
        parameters: TonConnectParameters,
        manifest: TonConnectManifest,
        signTonProofHandler: @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply,
        keeperVersion: String
    ) async throws -> TonConnect.ConnectEventSuccess {
        guard let requestOrigin = parameters.requestPayload.manifestUrl.normalizedOrigin,
              let manifestOrigin = manifest.url.normalizedOrigin,
              requestOrigin == manifestOrigin
        else {
            throw TonConnectManifestError.invalidManifest
        }
        guard wallet.isTonconnectAvailable else {
            throw
                TonConnectServiceError.unsupportedWalletKind(
                    walletKind: wallet.identity.kind
                )
        }
        return try await TonConnectResponseBuilder
            .buildConnectEventSuccesResponse(
                requestPayloadItems: parameters.requestPayload.items,
                wallet: wallet,
                keeperVersion: keeperVersion,
                manifest: manifest,
                signTonProof: signTonProofHandler
            )
    }

    func encryptSuccessResponse(
        _ successResponse: TonConnect.ConnectEventSuccess,
        parameters: TonConnectParameters,
        sessionCrypto: TonConnectSessionCrypto
    ) throws -> String {
        let responseData = try JSONEncoder().encode(successResponse)
        guard let receiverPublicKey = Data(strictHex: parameters.clientId) else {
            throw TonConnectServiceError.incorrectClientId
        }
        let response = try sessionCrypto.encrypt(
            message: responseData,
            receiverPublicKey: receiverPublicKey
        )
        return response.base64EncodedString()
    }

    func storeConnectedApp(
        wallet: Wallet,
        sessionCrypto: TonConnectSessionCrypto,
        parameters: TonConnectParameters,
        manifest: TonConnectManifest,
        connectionType: TonConnectApp.ConnectionType
    ) throws {
        try Self.tonConnectAppsLock.withLock {
            let tonConnectApp = TonConnectApp(
                clientId: parameters.clientId,
                manifest: manifest,
                manifestURL: parameters.requestPayload.manifestUrl,
                keyPair: sessionCrypto.keyPair,
                connectionType: connectionType
            )

            if let apps = try? tonConnectAppsVault.loadValue(key: wallet) {
                try tonConnectAppsVault.saveValue(apps.addApp(tonConnectApp), for: wallet)
            } else {
                let apps = TonConnectApps(apps: [tonConnectApp])
                try tonConnectAppsVault.saveValue(apps, for: wallet)
            }
        }
    }

    func confirmConnectionRequest(
        body: String,
        sessionCrypto: TonConnectSessionCrypto,
        parameters: TonConnectParameters
    ) async throws {
        let resp = try await tonConnectBridgeAPIClientProvider.tonConnectBridgerAPIClient().message(
            query: .init(
                client_id: sessionCrypto.sessionId,
                to: parameters.clientId,
                ttl: 300
            ),
            body: .plainText(.init(stringLiteral: body))
        )
        _ = try resp.ok.body.json
    }

    func getConnectedApps(forWallet wallet: Wallet) throws -> TonConnectApps {
        try Self.tonConnectAppsLock.withLock {
            try getConnectedAppsLocked(forWallet: wallet)
        }
    }

    func disconnectApp(_ app: TonConnectApp, wallet: Wallet) throws {
        try Self.tonConnectAppsLock.withLock {
            let apps = try getConnectedAppsLocked(forWallet: wallet)
            let updatedApps = apps.removeApp(app)
            try tonConnectAppsVault.saveValue(updatedApps, for: wallet)
        }
    }

    func disconnectApp(_ clientId: String, wallet: Wallet) throws {
        try Self.tonConnectAppsLock.withLock {
            let apps = try getConnectedAppsLocked(forWallet: wallet)
            let updatedApps = apps.removeApp(clientId: clientId)
            try tonConnectAppsVault.saveValue(updatedApps, for: wallet)
        }
    }

    func disconnectApp(_ idx: Int, wallet: Wallet) throws {
        try Self.tonConnectAppsLock.withLock {
            let apps = try getConnectedAppsLocked(forWallet: wallet)
            let updatedApps = apps.removeApp(at: idx)
            try tonConnectAppsVault.saveValue(updatedApps, for: wallet)
        }
    }

    private func getConnectedAppsLocked(forWallet wallet: Wallet) throws -> TonConnectApps {
        let apps = try tonConnectAppsVault.loadValue(key: wallet)
        let preservedApps = apps.apps.filter(\.shouldPreserveStoredConnection)
        guard preservedApps.count != apps.apps.count else {
            return apps
        }

        let result = TonConnectApps(apps: preservedApps)
        try tonConnectAppsVault.saveValue(result, for: wallet)
        return result
    }

    func cancelRequest(appRequest: TonConnect.SendTransactionRequest, app: TonConnectApp) async throws {
        let sessionCrypto = try TonConnectSessionCrypto(privateKey: app.keyPair.privateKey)
        let body = try TonConnectResponseBuilder.buildSendTransactionResponseError(
            sessionCrypto: sessionCrypto,
            errorCode: .userDeclinedAction,
            id: appRequest.id,
            clientId: app.clientId
        )
        _ = try await tonConnectBridgeAPIClientProvider.tonConnectBridgerAPIClient().message(
            query: .init(
                client_id: sessionCrypto.sessionId,
                to: app.clientId,
                ttl: 300
            ),
            body: .plainText(.init(stringLiteral: body))
        )
    }

    func confirmSignRequest(signed: SignedDataResult, appRequest: TonConnect.SignDataRequest, app: TonConnectApp) async throws {
        let sessionCrypto = try TonConnectSessionCrypto(privateKey: app.keyPair.privateKey)
        let body = try TonConnectResponseBuilder
            .buildSignDataResponseSuccess(sessionCrypto: sessionCrypto, signed: signed, id: appRequest.id, clientId: app.clientId)

        _ = try await tonConnectBridgeAPIClientProvider.tonConnectBridgerAPIClient().message(
            query: .init(
                client_id: sessionCrypto.sessionId,
                to: app.clientId,
                ttl: 300
            ),
            body: .plainText(.init(stringLiteral: body))
        )
    }

    func cancelSignRequest(appRequest: TonConnect.SignDataRequest, app: TonConnectApp) async throws {
        let sessionCrypto = try TonConnectSessionCrypto(privateKey: app.keyPair.privateKey)
        let body = try TonConnectResponseBuilder.buildSendTransactionResponseError(
            sessionCrypto: sessionCrypto,
            errorCode: .userDeclinedAction,
            id: appRequest.id,
            clientId: app.clientId
        )
        _ = try await tonConnectBridgeAPIClientProvider.tonConnectBridgerAPIClient().message(
            query: .init(
                client_id: sessionCrypto.sessionId,
                to: app.clientId,
                ttl: 300
            ),
            body: .plainText(.init(stringLiteral: body))
        )
    }

    func confirmRequest(boc: String, appRequest: TonConnect.SendTransactionRequest, app: TonConnectApp) async throws {
        let sessionCrypto = try TonConnectSessionCrypto(privateKey: app.keyPair.privateKey)
        let body = try TonConnectResponseBuilder
            .buildSendTransactionResponseSuccess(
                sessionCrypto: sessionCrypto,
                boc: boc,
                id: appRequest.id,
                clientId: app.clientId
            )

        _ = try await tonConnectBridgeAPIClientProvider.tonConnectBridgerAPIClient().message(
            query: .init(
                client_id: sessionCrypto.sessionId,
                to: app.clientId,
                ttl: 300
            ),
            body: .plainText(.init(stringLiteral: body))
        )
    }

    func confirmDisconnectRequest(appRequest: TonConnect.DisconnectRequest, app: TonConnectApp) async throws {
        let sessionCrypto = try TonConnectSessionCrypto(privateKey: app.keyPair.privateKey)
        let body = try TonConnectResponseBuilder
            .buildDisconnectResponseSuccess(
                sessionCrypto: sessionCrypto,
                id: appRequest.id,
                clientId: app.clientId
            )

        _ = try await tonConnectBridgeAPIClientProvider.tonConnectBridgerAPIClient().message(
            query: .init(
                client_id: sessionCrypto.sessionId,
                to: app.clientId,
                ttl: 300
            ),
            body: .plainText(.init(stringLiteral: body))
        )
    }

    func getLastEventId() throws -> String {
        try tonConnectRepository.getLastEventId().lastEventId
    }

    func saveLastEventId(_ lastEventId: String) throws {
        try tonConnectRepository.saveLastEventId(TonConnectLastEventId(lastEventId: lastEventId))
    }

    func loadManifest(url: URL) async throws -> TonConnectManifest {
        try await manifestLoader.load(url: url)
    }
}
