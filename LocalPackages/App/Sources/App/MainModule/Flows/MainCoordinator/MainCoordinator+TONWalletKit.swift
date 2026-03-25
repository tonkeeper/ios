import DisconnectDappToast
import KeeperCore
import TKCoordinator
import TKCore
import TKFeatureFlags
import TKLocalize
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
                print("AppCoordinator: Failed to setup TONWalletKit: \(error)")
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
            tonConnectAppsStore: keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore,
            request: connectionRequest
        )

        // Create parameters from event
        let parameters = TonConnectParameters(event: event, manifestUrl: manifestUrl)

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
                try? await connectionRequest.reject()
            }
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        coordinator.didConnect = { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        coordinator.didRequestOpeningBrowser = { [weak self] manifest in
            self?.openDapp(title: manifest.name, url: manifest.url)
        }

        addChild(coordinator)
        coordinator.start()
    }
}

// MARK: - TONWalletKit Coordinator Connector

@MainActor
public struct TONWalletKitCoordinatorConnector: TonConnectConnectCoordinatorConnector {
    private let tonConnectAppsStore: TonConnectAppsStore
    private let request: TONWalletConnectionRequest

    init(
        tonConnectAppsStore: TonConnectAppsStore,
        request: TONWalletConnectionRequest
    ) {
        self.tonConnectAppsStore = tonConnectAppsStore
        self.request = request
    }

    public func connect(
        wallet: Wallet,
        parameters: TonConnectParameters,
        manifest: TonConnectManifest,
        signTonProofHandler: @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply
    ) async throws {
        if request.event.isJsBridge == true {
            try await tonConnectAppsStore.connectWalletKitBridgeDapp(
                wallet: wallet,
                parameters: parameters,
                manifest: manifest,
                signTonProofHandler: signTonProofHandler,
                keeperVersion: InfoProvider
                    .appVersion(),
                request: request
            )
        } else {
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
}

public struct TONWalletKitSignDataResultHandler: SignDataResultHandler {
    public var didCancelHandler: (() -> Void)?

    private let signDataRequest: TONWalletSignDataRequest
    private let app: TonConnectApp

    public init(signDataRequest: TONWalletSignDataRequest, app: TonConnectApp) {
        self.signDataRequest = signDataRequest
        self.app = app
    }

    public func didSign(signedData: SignedDataResult) {
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
                print("Log: Failed to approve sign data: \(error)")
            }
        }
    }

    public func didFail(error: SignDataRequestFailure) {
        Task {
            try? await signDataRequest.reject(reason: error.localizedDescription)
        }
    }

    public func didCancel() {
        didCancelHandler?()
        Task {
            try? await signDataRequest.reject()
        }
    }
}
