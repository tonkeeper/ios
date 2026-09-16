import AppUI
import KeeperCore
import TKCoordinator
import TKCore
import TKFeatureFlags
import TKLocalize
import TKLogging
import TKUIKit
import TonSwift
import TONWalletKit
import UIKit

// MARK: - TONWalletKit Events Handling

extension MainCoordinator: TONWalletKitEventsObserver {
    /// Sets up TONWalletKit events observation when feature flag is enabled
    func setupTONWalletKitIfNeeded() throws {
        guard keeperCoreMainAssembly.configurationAssembly.configuration.featureEnabled(.walletKitEnabled) else {
            return
        }
        let kit = keeperCoreMainAssembly.tonWalletKitAssembly.tonWalletKit
        let eventsHandler = keeperCoreMainAssembly.tonWalletKitAssembly.eventsHandler
        eventsHandler.addWalletKitObserver(self)

        try kit.add(eventsHandler: eventsHandler)

        Task {
            do {
                try await kit.initialize()

                let walletsSynchronizer = keeperCoreMainAssembly.tonWalletKitAssembly.walletsSynchronizer

                await walletsSynchronizer.syncWallets()
                await walletsSynchronizer.startAutoSync()
            } catch {
                Log.e(
                    "\(String(reflecting: Self.self)): failed to initialize TONWalletKit",
                    extraInfo: [
                        "error": error.localizedDescription,
                    ]
                )
            }
        }
    }

    // MARK: - TONWalletKitEventsObserver

    public func didReceiveConnectRequest(_ request: TONWalletConnectionRequest) {
        handle(connectionRequest: request)
    }

    public func didReceiveTransactionRequest(_ request: TONWalletSendTransactionRequest, wallet: Wallet, app: TonConnectApp) {
        handle(sendTransactionRequest: request, wallet: wallet, app: app)
    }

    public func didReceiveSignDataRequest(_ request: TONWalletSignDataRequest, wallet: Wallet, app: TonConnectApp) {
        handle(signDataRequest: request, wallet: wallet, app: app)
    }

    // MARK: - Transaction Request Handling

    private func handle(
        sendTransactionRequest: TONWalletSendTransactionRequest,
        wallet: Wallet,
        app: TonConnectApp
    ) {
        guard let signRawRequest = SignRawRequest(request: sendTransactionRequest.event.request) else {
            return
        }

        var resultHandler = TONWalletKitSignRawResultHandler(
            transactionRequest: sendTransactionRequest,
            app: app
        )
        resultHandler.didCancelHandler = { [weak self] in
            self?.showTonConnectDisconnectAppToast(app: app)
        }

        openSignRaw(
            wallet: wallet,
            transferProvider: {
                .signRaw(signRawRequest, forceRelayer: false)
            },
            resultHandler: resultHandler,
            sendFrom: .tonconnectRemote,
            initiatedBy: .tonconnectRemote,
            dappUrl: app.manifest.host,
            redAnalyticsConfiguration: .init(
                flow: .tonConnect,
                operation: .confirmTransaction,
                attemptSource: .tonconnectRemote,
                staticMetadata: [
                    .dappHost: app.manifest.host,
                    .connectionType: app.connectionType.rawValue,
                ]
            )
        )
    }

    // MARK: - Sign Data Request Handling

    private func handle(
        signDataRequest: TONWalletSignDataRequest,
        wallet: Wallet,
        app: TonConnectApp
    ) {
        var resultHandler = TONWalletKitSignDataResultHandler(
            signDataRequest: signDataRequest,
            app: app
        )
        resultHandler.didCancelHandler = { [weak self] in
            self?.showTonConnectDisconnectAppToast(app: app)
        }

        openSignData(
            wallet: wallet,
            dappUrl: app.manifest.host,
            signRequest: TonConnect.SignDataRequest(request: signDataRequest),
            resultHandler: resultHandler,
            redAnalyticsConfiguration: .init(
                flow: .tonConnect,
                operation: .confirmTransaction,
                attemptSource: .tonconnectRemote,
                staticMetadata: [
                    .dappHost: app.manifest.host,
                    .connectionType: app.connectionType.rawValue,
                ]
            )
        )
    }

    // MARK: - Connect Request Handling

    private func handle(connectionRequest: TONWalletConnectionRequest) {
        let event = connectionRequest.event

        if let error = event.preview.manifestFetchErrorCode {
            Log.e(
                "wallet_kit_error",
                extraInfo: [
                    "type": "Manifest fetching error",
                    "error": "\(error)",
                ]
            )
        }

        guard let windowScene = router.rootViewController.view.window?.windowScene else {
            return
        }

        // Get manifest URL from dApp info
        guard let dAppInfo = event.dAppInfo,
              let manifestUrl = dAppInfo.manifestUrl,
              let manifest = TonConnectManifest(dAppInfo: dAppInfo)
        else {
            return
        }

        let window = TKWindow(windowScene: windowScene)
        window.windowLevel = .tonConnectConnect
        let windowRouter = WindowRouter(window: window)

        // Create connector that uses TONWalletKit's approve/reject
        let connector = TONWalletKitCoordinatorConnector(
            kit: keeperCoreMainAssembly.tonWalletKitAssembly.tonWalletKit,
            tonConnectAppsStore: keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore,
            request: connectionRequest
        )

        let source = event.from
            .flatMap { from in
                keeperCoreMainAssembly.tonConnectAssembly
                    .tonConnectAppsStore
                    .consumePendingConnectionSource(
                        clientId: from,
                        manifestURL: manifestUrl
                    )
            } ?? .deeplink

        // Create parameters from event
        let eventParameters = TonConnectParameters(
            event: event,
            manifestUrl: manifestUrl
        )
        let parameters = TonConnectParameters(
            version: eventParameters.version,
            clientId: eventParameters.clientId,
            requestPayload: eventParameters.requestPayload,
            returnStrategy: eventParameters.returnStrategy,
            source: source
        )

        let coordinator = TonConnectModule(
            dependencies: TonConnectModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        ).createConnectCoordinator(
            router: windowRouter,
            flow: .common,
            connector: connector,
            parameters: parameters,
            manifest: manifest,
            showWalletPicker: true,
            isSilentConnect: false
        )

        coordinator.didCancel = { [weak self, weak coordinator] in
            Task {
                do {
                    try await connectionRequest.reject()
                } catch {
                    Log.e(
                        "\(String(reflecting: Self.self)): failed to reject TONWalletKit connection request after user cancelled",
                        extraInfo: [
                            "error": error.localizedDescription,
                        ]
                    )
                }
            }
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        coordinator.didConnect = { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        coordinator.didRequestOpeningBrowser = { [weak self] manifest in
            self?.openDapp(title: manifest.name, url: manifest.url, analyticsFrom: .deepLink)
        }

        addChild(coordinator)
        coordinator.start()
    }
}

// MARK: - TONWalletKit Coordinator Connector

@MainActor
struct TONWalletKitCoordinatorConnector: TonConnectConnectCoordinatorConnector {
    private let kit: TONWalletKit
    private let tonConnectAppsStore: TonConnectAppsStore
    private let request: TONWalletConnectionRequest

    init(
        kit: TONWalletKit,
        tonConnectAppsStore: TonConnectAppsStore,
        request: TONWalletConnectionRequest
    ) {
        self.kit = kit
        self.tonConnectAppsStore = tonConnectAppsStore
        self.request = request
    }

    func connect(
        wallet: Wallet,
        parameters: TonConnectParameters,
        manifest: TonConnectManifest,
        signTonProofHandler: @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply
    ) async throws {
        let walletId: String?
        do {
            walletId = try wallet.walletKitIdentifier
        } catch {
            Log.e(
                "\(String(reflecting: Self.self)): failed to resolve walletKitIdentifier for connect",
                extraInfo: [
                    "error": error.localizedDescription,
                    "walletId": wallet.id,
                ]
            )
            walletId = nil
        }
        if let walletId {
            if await !kit.has(walletId: walletId) {
                _ = try await kit.add(walletAdapter: TONWalletAdapter(tonWallet: wallet))
            }
        }

        try await tonConnectAppsStore.connectWalletKit(
            wallet: wallet,
            parameters: parameters,
            manifest: manifest,
            signTonProofHandler: signTonProofHandler,
            keeperVersion: InfoProvider.appVersion(),
            request: request
        )
    }
}

struct TONWalletKitSignDataResultHandler: SignDataResultHandler {
    var didCancelHandler: (() -> Void)?

    private let signDataRequest: TONWalletSignDataRequest
    private let app: TonConnectApp

    init(signDataRequest: TONWalletSignDataRequest, app: TonConnectApp) {
        self.signDataRequest = signDataRequest
        self.app = app
    }

    func didSign(signedData: SignedDataResult) {
        Task {
            do {
                let signature = try TONBase64(base64Encoded: signedData.signature)

                guard let data = signature.data else {
                    throw "No valid base64 signed data found"
                }

                let response = TONSignDataApprovalResponse(
                    signature: TONHex(data: data),
                    timestamp: Int(signedData.timestamp),
                    domain: app.manifest.host
                )
                try await signDataRequest.approve(response: response)
            } catch {
                Log.e(
                    "\(String(reflecting: Self.self)): failed to approve sign-data request",
                    extraInfo: [
                        "error": error.localizedDescription,
                        "dappHost": app.manifest.host,
                    ]
                )
            }
        }
    }

    func didFail(error: SignDataRequestFailure) {
        Task {
            do {
                try await signDataRequest.reject(reason: error.localizedDescription)
            } catch {
                Log.e(
                    "\(String(reflecting: Self.self)): failed to reject sign-data request after didFail",
                    extraInfo: [
                        "error": error.localizedDescription,
                        "dappHost": app.manifest.host,
                    ]
                )
            }
        }
    }

    func didCancel() {
        didCancelHandler?()
        Task {
            do {
                try await signDataRequest.reject()
            } catch {
                Log.e(
                    "\(String(reflecting: Self.self)): failed to reject sign-data request after user cancel",
                    extraInfo: [
                        "error": error.localizedDescription,
                        "dappHost": app.manifest.host,
                    ]
                )
            }
        }
    }
}

private extension TONWalletKit {
    func has(walletId: String) async -> Bool {
        do {
            _ = try await wallet(id: walletId)
            return true
        } catch {
            return false
        }
    }
}
