import BigInt
import Foundation
import KeeperCoreComponents
import TKLogging
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
    private let urlSession: URLSession
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
        self.urlSession = urlSession
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
        let tonConnectApp = TonConnectApp(
            clientId: parameters.clientId,
            manifest: manifest,
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
        try tonConnectAppsVault.loadValue(key: wallet)
    }

    func disconnectApp(_ app: TonConnectApp, wallet: Wallet) throws {
        let apps = try getConnectedApps(forWallet: wallet)
        let updatedApps = apps.removeApp(app)
        try tonConnectAppsVault.saveValue(updatedApps, for: wallet)
    }

    func disconnectApp(_ clientId: String, wallet: Wallet) throws {
        let apps = try getConnectedApps(forWallet: wallet)
        let updatedApps = apps.removeApp(clientId: clientId)
        try tonConnectAppsVault.saveValue(updatedApps, for: wallet)
    }

    func disconnectApp(_ idx: Int, wallet: Wallet) throws {
        let apps = try getConnectedApps(forWallet: wallet)
        let updatedApps = apps.removeApp(at: idx)
        try tonConnectAppsVault.saveValue(updatedApps, for: wallet)
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
        let urls = [url, url.proxyURL].compactMap { $0 }

        let manifest = try await loadManifest(urls: urls)

        guard manifest.url.host?.contains(".") == true else {
            throw TonConnectManifestError.invalidManifest
        }
        return manifest
    }

    private func loadManifest(urls: [URL]) async throws -> TonConnectManifest {
        for (i, url) in urls.enumerated() {
            let isLastUrl = i == urls.count - 1

            do {
                let (data, _) = try await urlSession.data(from: url)
                let jsonDecoder = JSONDecoder()
                return try jsonDecoder.decode(TonConnectManifest.self, from: data)
            } catch {
                guard isLastUrl else { continue }

                switch error {
                case is DecodingError:
                    logManifestLoadingFailed(error: .invalidManifest, url: url)
                    throw TonConnectManifestError.invalidManifest
                case let urlError as URLError:
                    if urlError.code == URLError.Code.badURL {
                        logManifestLoadingFailed(error: .incorrectURL, url: url)
                        throw TonConnectManifestError.incorrectURL
                    } else {
                        logManifestLoadingFailed(error: .loadFailed(error: urlError), url: url)
                        throw TonConnectManifestError.loadFailed(error: urlError)
                    }
                default:
                    logManifestLoadingFailed(error: .loadFailed(error: error), url: url)
                    throw TonConnectManifestError.loadFailed(error: error)
                }
            }
        }

        throw TonConnectManifestError.incorrectURL
    }

    private func logManifestLoadingFailed(error: TonConnectManifestError, url: URL) {
        let errorDesctiption: String

        switch error {
        case .incorrectURL: errorDesctiption = "Incorrect URL"
        case .invalidManifest: errorDesctiption = "Invalid manifest"
        case let .loadFailed(error): errorDesctiption = error.localizedDescription
        }

        Log.e(
            "\(String(reflecting: Self.self)): manifest fetching failed",
            extraInfo: [
                "error": errorDesctiption,
                "url": url.absoluteString,
            ]
        )
    }
}
