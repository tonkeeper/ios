import KeeperCore
import SignRaw
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKScreenKit
import TKUIKit
import TONWalletKit
import UIKit

enum DidRequireSignError: Swift.Error {
    case unknown
}

@MainActor
final class DappCoordinator: RouterCoordinator<ViewControllerRouter> {
    var didHandleDeeplink: ((_ deeplink: Deeplink) -> Void)?

    private let dapp: Dapp
    private let isSilentConnect: Bool
    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly

    var didRequestOpenBuySell: ((_ wallet: Wallet, _ isInternalPurchasing: Bool) -> Void)?

    init(
        router: ViewControllerRouter,
        dapp: Dapp,
        isSilentConnect: Bool,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) {
        self.dapp = dapp
        self.isSilentConnect = isSilentConnect
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly

        super.init(router: router)
    }

    override func start() {
        if keeperCoreMainAssembly.configurationAssembly.configuration.featureEnabled(.walletKitEnabled) {
            openWalletKitDappModule(dapp)
        } else {
            openDappModule(dapp)
        }
    }

    private func openWalletKitDappModule(_ dapp: Dapp) {
        let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet
        let messageHandler = DefaultDappMessageHandler()
        let eventsHandler = TONConnectWebViewEventsHandler(dapp: dapp, wallet: wallet)
        let walletKit = keeperCoreMainAssembly.tonWalletKitAssembly.tonWalletKit
        let module = DappWalletKitAssembly.module(
            dapp: dapp,
            analyticsProvider: coreAssembly.analyticsProvider,
            deeplinkHandler: { [weak self] deeplink in
                self?.didHandleDeeplink?(deeplink)
            },
            messageHandler: messageHandler,
            wallet: wallet,
            walletKit: walletKit,
            eventsHandler: eventsHandler
        )

        messageHandler.fetch = { [weak self] url, params, completion in
            guard let self else {
                completion(.error(.unknownError))
                return
            }
            Task {
                do {
                    let data = try await self.keeperCoreMainAssembly.servicesAssembly.dappFetchService().fetch(url, params: params)
                    completion(.response(data))

                } catch {
                    completion(.error(.unknownError))
                    print(error)
                }
            }
        }

        messageHandler.toggleLandscape = { [weak moduleInput = module.input] landscapeEnabled in
            moduleInput?.setLandscapeMode(isEnabled: landscapeEnabled)
        }

        // kinda kludge for case with different manifestUrl and app.url to show domain correctly on SignData bottomsheet
        var manifestUrl: URL?
        eventsHandler.connectionEventHandler = { [weak self, weak moduleView = module.view] protocolVersion, payload, request in
            guard let self, let moduleView else {
                return
            }
            manifestUrl = payload.manifestUrl

            let connector = TONWalletKitCoordinatorConnector(
                tonConnectAppsStore: self.keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore,
                request: request
            )

            self.performConnect(
                protocolVersion: protocolVersion,
                payload: payload,
                connector: connector,
                fromViewController: moduleView,
                completion: { _ in }
            )
        }

        weak let moduleView = module.view
        eventsHandler.sendTransactionEventHandler = { [weak self] _, request, completion in
            guard let self, let moduleView, let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else {
                completion(.error(.unknownError))
                return
            }
            let appId = manifestUrl?.host ?? dapp.url.host
            self.openSend(
                wallet: wallet,
                dapp: dapp,
                appRequest: request,
                appId: appId,
                fromViewController: moduleView,
                completion: completion
            )
        }

        eventsHandler.signDataEventHandler = { [weak self] app, request, completion in
            guard let self, let moduleView, let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else {
                completion(.error(.unknownError))
                return
            }
            self.openSignData(
                wallet: wallet,
                dappUrl: manifestUrl?.host ?? app.url.host ?? "",
                appRequest: request,
                fromViewController: moduleView,
                router: router,
                completion: completion
            )
        }

        module.output.didShareDappURL = { [weak self] in
            self?.openSharingSheet(app: $0, url: $1)
        }

        module.view.modalPresentationStyle = .fullScreen
        router.rootViewController.topPresentedViewController().present(module.view, animated: true)
    }

    private func openDappModule(_ dapp: Dapp) {
        let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet
        let messageHandler = DefaultDappMessageHandler()
        let module = DappAssembly.module(
            dapp: dapp,
            analyticsProvider: coreAssembly.analyticsProvider,
            deeplinkHandler: { deeplink in
                self.didHandleDeeplink?(deeplink)
            },
            messageHandler: messageHandler,
            wallet: wallet
        )

        // kinda kludge for case with different manifestUrl and app.url to show domain correctly on SignData bottomsheet
        var manifestUrl: URL?
        messageHandler.connect = { [weak self, weak moduleView = module.view] protocolVersion, payload, completion in
            guard let self, let moduleView else {
                completion(.error(.unknownError))
                return
            }
            manifestUrl = payload.manifestUrl

            let connector = BridgeTonConnectConnectCoordinatorConnector(
                tonConnectAppsStore: self.keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore
            ) {
                completion($0)
            }

            self.performConnect(
                protocolVersion: protocolVersion,
                payload: payload,
                connector: connector,
                fromViewController: moduleView,
                completion: completion
            )
        }

        messageHandler.fetch = { [weak self] url, params, completion in
            guard let self else {
                completion(.error(.unknownError))
                return
            }
            Task {
                do {
                    let data = try await self.keeperCoreMainAssembly.servicesAssembly.dappFetchService().fetch(url, params: params)
                    completion(.response(data))

                } catch {
                    completion(.error(.unknownError))
                    Log.w("\(error)")
                }
            }
        }

        messageHandler.reconnect = { [weak self] dapp, completion in
            guard let self,
                  let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet
            else {
                completion(.error(.unknownError))
                return
            }

            let result = self.keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore.reconnectBridgeDapp(
                wallet: wallet,
                appUrl: dapp.url,
                keeperVersion: InfoProvider.appVersion()
            )
            completion(result)
        }

        messageHandler.disconnect = {
            [weak self] dapp in
            guard let self,
                  let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else { return }
            try? self.keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore.disconnectBridge(wallet: wallet, appUrl: dapp.url)
        }

        weak let moduleView = module.view
        messageHandler.sendTransaction = {
            [weak self] _, request, completion in
            guard let self, let moduleView, let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else {
                completion(.error(.unknownError))
                return
            }
            let appId = manifestUrl?.host ?? dapp.url.host
            self.openSend(
                wallet: wallet,
                dapp: dapp,
                appRequest: request,
                appId: appId,
                fromViewController: moduleView,
                completion: completion
            )
        }

        messageHandler.signData = {
            [weak self] app, request, completion in
            guard let self, let moduleView, let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else {
                completion(.error(.unknownError))
                return
            }
            self.openSignData(
                wallet: wallet,
                dappUrl: manifestUrl?.host ?? app.url.host ?? "",
                appRequest: request,
                fromViewController: moduleView,
                router: router,
                completion: completion
            )
        }

        messageHandler.toggleLandscape = { [weak moduleInput = module.input] landscapeEnabled in
            moduleInput?.setLandscapeMode(isEnabled: landscapeEnabled)
        }

        module.output.didShareDappURL = { [weak self] in
            self?.openSharingSheet(app: $0, url: $1)
        }

        module.view.modalPresentationStyle = .fullScreen
        router.rootViewController.topPresentedViewController().present(module.view, animated: true)
    }

    private func performConnect(
        protocolVersion: Int,
        payload: TonConnectRequestPayload,
        connector: TonConnectConnectCoordinatorConnector,
        fromViewController: UIViewController,
        completion: @escaping (TonConnectAppsStore.ConnectResult) -> Void
    ) {
        ToastPresenter.hideAll()
        ToastPresenter.showToast(configuration: .loading)
        Task {
            let trace = Trace(name: "perform_connect")
            do {
                let manifest = try await keeperCoreMainAssembly.tonConnectAssembly.tonConnectService().loadManifest(
                    url: payload.manifestUrl
                )
                let parameters = TonConnectParameters(
                    version: .v2,
                    clientId: UUID().uuidString,
                    requestPayload: payload
                )
                trace.setValue(manifest.url.absoluteString, forAttribute: "manifest")
                await MainActor.run {
                    ToastPresenter.hideToast()
                    handleLoadedManifest(
                        parameters: parameters,
                        manifest: manifest,
                        connector: connector,
                        completion: completion
                    )
                }
                trace.setValue("success", forAttribute: "result")
            } catch {
                await MainActor.run {
                    ToastPresenter.hideToast()
                    completion(.error(.appManifestNotFound))
                }
                trace.setValue("fail", forAttribute: "result")
            }
            trace.stop()
        }

        func handleLoadedManifest(
            parameters: TonConnectParameters,
            manifest: TonConnectManifest,
            connector: TonConnectConnectCoordinatorConnector,
            completion: @escaping (TonConnectAppsStore.ConnectResult) -> Void
        ) {
            guard let windowScene = fromViewController.windowScene else {
                completion(.error(.unknownError))
                return
            }
            let window = TKWindow(windowScene: windowScene)
            window.windowLevel = .tonConnectConnect
            let router = WindowRouter(window: window)

            let coordinator = TonConnectConnectCoordinator(
                router: router,
                flow: .common,
                connector: connector,
                parameters: parameters,
                manifest: manifest,
                showWalletPicker: false,
                isSilentConnect: isSilentConnect,
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )

            coordinator.didCancel = { [weak self, weak coordinator] in
                completion(.error(.userDeclinedTheConnection))

                guard let coordinator else { return }
                self?.removeChild(coordinator)
            }

            coordinator.didConnect = { [weak self, weak coordinator] in
                guard let coordinator else { return }
                self?.removeChild(coordinator)
            }

            coordinator.didFail = { [weak self, weak coordinator] in
                completion(.error(.unknownError))

                guard let coordinator else { return }
                self?.removeChild(coordinator)
            }

            addChild(coordinator)
            coordinator.start()
        }
    }

    private func openSignData(
        wallet: Wallet,
        dappUrl: String,
        appRequest: TonConnect.SignDataRequest,
        fromViewController: UIViewController,
        router: ViewControllerRouter,
        completion: @escaping (TonConnectAppsStore.SendResult) -> Void
    ) {
        let signHandler = DappSignDataResultHandler(appRequest: appRequest, connectionResponseHandler: completion)

        guard let windowScene = fromViewController.windowScene else {
            completion(.error(.unknownError))
            return
        }

        let didRequireSignHandler: (TonConnect.SignDataRequest, String, Wallet, ViewControllerRouter) async throws(SignDataSignError) -> SignedDataResult? = { [weak self] request, dappUrl, wallet, router async throws(SignDataSignError) in
            guard let self else {
                throw .cancelled
            }
            return try await self.didRequireSign(
                request: request,
                dappUrl: dappUrl,
                wallet: wallet,
                coordinator: self,
                router: router
            )
        }

        SignDataPresenter.presentSignData(
            windowScene: windowScene,
            windowLevel: .signData,
            wallet: wallet,
            dappUrl: dappUrl,
            request: appRequest,
            resultHandler: signHandler,
            didRequireSign: didRequireSignHandler,
            analyticsProvider: coreAssembly.analyticsProvider,
            redAnalyticsConfiguration: .init(
                flow: .tonConnect,
                operation: .confirmTransaction,
                attemptSource: .tonconnectLocal,
                staticMetadata: [
                    .dappHost: dappUrl,
                ]
            ),
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )
    }

    private func openSend(
        wallet: Wallet,
        dapp: Dapp,
        appRequest: TonConnect.SendTransactionRequest,
        appId: String?,
        fromViewController: UIViewController,
        completion: @escaping (TonConnectAppsStore.SendResult) -> Void
    ) {
        guard let windowScene = fromViewController.windowScene,
              let request = appRequest.params.first
        else {
            completion(.error(.unknownError))
            return
        }

        SignRawPresenter.presentSignRaw(
            windowScene: windowScene,
            windowLevel: .signRaw,
            wallet: wallet,
            transferProvider: {
                .signRaw(request, forceRelayer: false)
            },
            resultHandler: DappSignRawResultHandler(
                appRequest: appRequest,
                connectionResponseHandler: completion
            ),
            sendFrom: .tonconnectLocal,
            appId: appId,
            redAnalyticsConfiguration: .init(
                flow: .tonConnect,
                operation: .confirmTransaction,
                attemptSource: .tonconnectLocal,
                staticMetadata: [
                    .dappHost: appId ?? dapp.url.host,
                ]
            ),
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            didRequireSign: { [weak self] transferData, wallet, coordinator, router throws(WalletTransferSignError) in
                guard let self else {
                    throw .cancelled
                }
                return try await didRequireSign(
                    transferData: transferData,
                    wallet: wallet,
                    coordinator: coordinator,
                    router: router
                )
            },
            didRequestReplanishWallet: { [weak self] wallet, isInternalPurchasing in
                self?.router.dismiss(animated: true) {
                    self?.didRequestOpenBuySell?(wallet, isInternalPurchasing)
                }
            }
        )
    }

    @MainActor
    func didRequireSign(
        transferData: TransferData,
        wallet: Wallet,
        coordinator: Coordinator,
        router: ViewControllerRouter
    ) async throws(WalletTransferSignError) -> SignedTransactions {
        let signCoordinator = WalletTransferSignCoordinator(
            router: router,
            wallet: wallet,
            transferData: transferData,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        return try await signCoordinator
            .handleSign(parentCoordinator: coordinator)
            .get()
    }

    @MainActor
    func didRequireSign(
        request: TonConnect.SignDataRequest,
        dappUrl: String,
        wallet: Wallet,
        coordinator: Coordinator,
        router: ViewControllerRouter
    ) async throws(SignDataSignError) -> SignedDataResult? {
        let signCoordinator = SignDataSignCoordinator(
            router: router,
            wallet: wallet,
            dappUrl: dappUrl,
            request: request,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        let result = await signCoordinator.handleSign(parentCoordinator: coordinator)

        switch result {
        case let .signed(data):
            return data
        case .cancel:
            throw SignDataSignError.cancelled
        case let .failed(error):
            throw error
        }
    }

    func openSharingSheet(app: Dapp, url: URL) {
        let module = DappSharingPopupAssembly.module(
            dapp: dapp,
            url: url,
            keeperCoreAssembly: keeperCoreMainAssembly
        )

        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
        bottomSheetViewController.present(fromViewController: router.rootViewController.topPresentedViewController())
    }
}

private struct DappSignRawResultHandler: SignRawControllerResultHandler {
    private let appRequest: TonConnect.SendTransactionRequest
    private let connectionResponseHandler: (TonConnectAppsStore.SendResult) -> Void

    init(
        appRequest: TonConnect.SendTransactionRequest,
        connectionResponseHandler: @escaping (TonConnectAppsStore.SendResult) -> Void
    ) {
        self.appRequest = appRequest
        self.connectionResponseHandler = connectionResponseHandler
    }

    func didConfirm(boc: String) {
        let sendTransactionResponse = TonConnect.SendResponse.success(
            .init(
                result: boc,
                id: appRequest.id
            )
        )
        guard let response = try? JSONEncoder().encode(sendTransactionResponse) else {
            connectionResponseHandler(.error(.unknownError))
            return
        }
        connectionResponseHandler(.response(response))
    }

    func didFail(error: SomeOf<TransferError, TransactionConfirmationError>) {
        connectionResponseHandler(.error(.unknownError))
    }

    func didCancel() {
        connectionResponseHandler(.error(.userDeclinedAction))
    }
}

private struct DappSignDataResultHandler: SignDataResultHandler {
    private let appRequest: TonConnect.SignDataRequest
    private let connectionResponseHandler: (TonConnectAppsStore.SendResult) -> Void

    init(
        appRequest: TonConnect.SignDataRequest,
        connectionResponseHandler: @escaping (TonConnectAppsStore.SendResult) -> Void
    ) {
        self.appRequest = appRequest
        self.connectionResponseHandler = connectionResponseHandler
    }

    func didSign(signedData: SignedDataResult) {
        let signDataResponse = TonConnect.SendResponse.success(
            .init(
                result: signedData,
                id: appRequest.id
            )
        )
        guard let response = try? JSONEncoder().encode(signDataResponse) else {
            connectionResponseHandler(.error(.unknownError))
            return
        }
        connectionResponseHandler(.response(response))
    }

    func didFail(error: SignDataRequestFailure) {
        connectionResponseHandler(.error(.unknownError))
    }

    func didCancel() {
        connectionResponseHandler(.error(.userDeclinedAction))
    }
}
