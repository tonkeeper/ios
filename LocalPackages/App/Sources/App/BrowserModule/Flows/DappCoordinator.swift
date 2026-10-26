import KeeperCore
import SignRaw
import TKAppInfo
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKScreenKit
import TKUIKit
import UIKit

@MainActor
final class DappCoordinator: RouterCoordinator<ViewControllerRouter> {
    var didHandleDeeplink: ((_ deeplink: Deeplink, _ utm: UtmParameters) -> Void)?

    let dapp: Dapp
    private let analyticsSession: DappOpenAnalyticsSession
    private let isSilentConnect: Bool
    let coreAssembly: TKCore.CoreAssembly
    let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let explorerURLMatcher: BlockchainExplorerURLMatcher
    private let presentation: DappPresentation
    private weak var dappViewController: DappViewController?
    private let earnSession: EarnDappSession?

    var didRequestOpenBuySell: ((_ wallet: Wallet, _ isInternalPurchasing: Bool) -> Void)?

    init(
        router: ViewControllerRouter,
        dapp: Dapp,
        analyticsSession: DappOpenAnalyticsSession,
        isSilentConnect: Bool,
        presentation: DappPresentation = .modal,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) {
        self.dapp = dapp
        self.analyticsSession = analyticsSession
        self.isSilentConnect = isSilentConnect
        self.presentation = presentation
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.explorerURLMatcher = BlockchainExplorerURLMatcher(
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration
        )
        self.earnSession = EarnDappMatcher().matches(url: dapp.url)
            ? EarnDappSession(
                analyticsProvider: coreAssembly.analyticsProvider,
                openSession: analyticsSession,
                dappUrl: dapp.url.host
            )
            : nil

        super.init(router: router)
    }

    override func start() {
        analyticsSession.logClick()
        openDappModule(dapp)
    }

    private func openDappModule(_ dapp: Dapp) {
        let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet
        let configuration = keeperCoreMainAssembly.configurationAssembly.configuration
        let messageHandler = DefaultDappMessageHandler()
        let module = DappAssembly.module(
            dapp: dapp,
            analyticsSession: analyticsSession,
            deeplinkHandler: { deeplink, utm in
                self.didHandleDeeplink?(deeplink, utm)
            },
            deeplinkParser: keeperCoreMainAssembly.deeplinkParser,
            messageHandler: messageHandler,
            wallet: wallet,
            isSignMessageSupported: keeperCoreMainAssembly.tonConnectAssembly.isSignMessageEnabled
                && wallet?.isTonConnectSignMessageAvailable == true,
            explorerURLMatcher: explorerURLMatcher,
            earnFeaturedVaultsRepository: keeperCoreMainAssembly.repositoriesAssembly.earnFeaturedVaultsRepository(
                isEarnEnabled: configuration.featureEnabled(.earnEnabled),
                isAppStoreEnvironment: UIApplication.shared.isAppStoreEnvironment,
                configuration: configuration
            ),
            userAgent: coreAssembly.appInfoProvider.userAgent
        )
        dappViewController = module.view

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

        messageHandler.signMessage = {
            [weak self] _, request, completion in
            guard let self, let moduleView, let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else {
                completion(.error(.unknownError))
                return
            }
            let appId = manifestUrl?.host ?? dapp.url.host
            self.handleSignMessage(
                wallet: wallet,
                dapp: dapp,
                appRequest: request,
                appId: appId,
                fromViewController: moduleView,
                completion: completion
            )
        }

        messageHandler.signData = {
            [weak self] _, request, completion in
            guard let self,
                  let moduleView,
                  let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet,
                  let dappHost = moduleView.currentURL?.host,
                  !dappHost.isEmpty
            else {
                completion(.error(.unknownError))
                return
            }
            self.openSignData(
                wallet: wallet,
                dappUrl: dappHost,
                appRequest: request,
                fromViewController: moduleView,
                router: router,
                completion: completion
            )
        }

        if let earnSession {
            let provider = EarnEVMProvider(
                dapp: WalletConnectDapp(
                    name: dapp.name,
                    url: dapp.url.absoluteString,
                    description: dapp.description ?? "",
                    iconURL: dapp.icon?.absoluteString
                ),
                walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
                sign: { [weak self, signingService = keeperCoreMainAssembly.walletConnectAssembly.walletConnectSigningService] wallet, request throws(WalletConnectSigningError) in
                    try await signingService.sign(
                        passcodeProvider: { [weak self] in
                            guard let self else { return nil }
                            return await PasscodeInputCoordinator.getPasscode(
                                parentCoordinator: self,
                                parentRouter: self.router,
                                mnemonicAccess: self.keeperCoreMainAssembly.mnemonicAccess,
                                securityStore: self.keeperCoreMainAssembly.storesAssembly.securityStore,
                                analyticsProvider: self.coreAssembly.analyticsProvider,
                                reason: .dappRequest
                            )
                        },
                        wallet: wallet,
                        request: request
                    )
                }
            )
            provider.onEvent = { [weak moduleInput = module.input] event in
                moduleInput?.sendEVMEvent(event)
            }
            provider.onSigning = { event in
                earnSession.logSigning(event)
            }
            provider.onTransactionSent = { wallet, chain, transaction in
                earnSession.logTransactionSent(wallet: wallet, chain: chain, transaction: transaction)
            }
            messageHandler.ethRequest = { [weak self] request, completion in
                provider.handle(request, pageURL: self?.dappViewController?.currentURL, completion: completion)
            }
        }

        messageHandler.toggleLandscape = { [weak moduleInput = module.input] landscapeEnabled in
            moduleInput?.setLandscapeMode(isEnabled: landscapeEnabled)
        }

        messageHandler.navigateBack = { [weak self] in
            self?.closeDappModule(exitMethod: .page)
        }

        messageHandler.track = { [earnSession] event, params in
            earnSession?.trackPageEvent(name: event, params: params)
        }

        module.output.didShareDappURL = { [weak self] in
            self?.openSharingSheet(app: $0, url: $1)
        }
        module.output.didRequestClose = { [weak self] in
            self?.closeDappModule(exitMethod: .closeButton)
        }

        switch presentation {
        case .modal:
            module.view.modalPresentationStyle = .fullScreen
            router.rootViewController.modalPresentationSourceViewController().present(module.view, animated: true)
        case let .push(navigationController):
            module.view.didPop = { [weak self] byGesture in
                guard let self else { return }
                earnSession?.close(via: byGesture ? .systemBack : .other)
                didFinish?(self)
            }
            navigationController.pushViewController(module.view, animated: true)
        }
    }

    private func closeDappModule(exitMethod: EarnExitMethod = .other, completion: (() -> Void)? = nil) {
        earnSession?.close(via: exitMethod)
        switch presentation {
        case .modal:
            dappViewController?.dismiss(animated: true, completion: completion)
        case .push:
            guard let dappViewController,
                  let navigationController = dappViewController.navigationController,
                  let index = navigationController.viewControllers.firstIndex(of: dappViewController),
                  index > 0
            else {
                completion?()
                return
            }
            let pop = {
                navigationController.popToViewController(navigationController.viewControllers[index - 1], animated: true)
                guard let completion else { return }
                guard let transitionCoordinator = navigationController.transitionCoordinator else {
                    completion()
                    return
                }
                transitionCoordinator.animate(alongsideTransition: nil) { _ in completion() }
            }
            if let presented = navigationController.presentedViewController {
                presented.dismiss(animated: true, completion: pop)
            } else {
                pop()
            }
        }
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
                    requestPayload: payload,
                    source: .dapp
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
                let errorDescription: String

                switch error {
                case let error as TonConnectManifestError:
                    errorDescription = error.description
                default:
                    errorDescription = error.localizedDescription
                }

                await MainActor.run {
                    ToastPresenter.hideToast()
                    ToastPresenter.showToast(
                        configuration: ToastPresenter.Configuration(
                            title: errorDescription
                        )
                    )
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
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                injectedDappDomainProvider: { [weak fromViewController] in
                    (fromViewController as? DappViewController)?.currentURL?.host
                }
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
            mode: .sendTransaction,
            transferProvider: {
                .signRaw(request, forceRelayer: false)
            },
            resultHandler: DappSignRawResultHandler(
                appRequest: appRequest,
                connectionResponseHandler: completion
            ),
            sendFrom: .tonconnectLocal,
            appId: appId,
            initiatedBy: .tonconnectLocal,
            dappUrl: dapp.url.host,
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
                guard let self else { return }
                let openBuySell = didRequestOpenBuySell
                closeDappModule {
                    openBuySell?(wallet, isInternalPurchasing)
                }
            }
        )
    }

    private func handleSignMessage(
        wallet: Wallet,
        dapp: Dapp,
        appRequest: TonConnect.SignMessageRequest,
        appId: String?,
        fromViewController: UIViewController,
        completion: @escaping (TonConnectAppsStore.SendResult) -> Void
    ) {
        let sendService = keeperCoreMainAssembly.servicesAssembly.sendService()
        let isSignMessageEnabled = keeperCoreMainAssembly.tonConnectAssembly.isSignMessageEnabled
        Task { @MainActor [weak self, weak fromViewController] in
            do throws(TonConnectSignMessageValidationError) {
                try await TonConnectSignMessageValidation.validate(
                    appRequest.params,
                    wallet: wallet,
                    isSignMessageEnabled: isSignMessageEnabled,
                    sendService: sendService
                )
            } catch {
                ToastPresenter.showToast(configuration: .init(title: error.toastTitle))
                completion(.error(error.errorCode))
                return
            }
            guard let self, let fromViewController else {
                completion(.error(.unknownError))
                return
            }
            openSignMessage(
                wallet: wallet,
                dapp: dapp,
                appRequest: appRequest,
                appId: appId,
                fromViewController: fromViewController,
                completion: completion
            )
        }
    }

    private func openSignMessage(
        wallet: Wallet,
        dapp: Dapp,
        appRequest: TonConnect.SignMessageRequest,
        appId: String?,
        fromViewController: UIViewController,
        completion: @escaping (TonConnectAppsStore.SendResult) -> Void
    ) {
        guard let windowScene = fromViewController.windowScene else {
            completion(.error(.unknownError))
            return
        }

        SignRawPresenter.presentSignRaw(
            windowScene: windowScene,
            windowLevel: .signRaw,
            wallet: wallet,
            mode: .signMessage(appName: signMessageAppName(wallet: wallet, dapp: dapp)),
            transferProvider: {
                .signRaw(appRequest.params, forceRelayer: false)
            },
            resultHandler: DappSignMessageResultHandler(
                appRequest: appRequest,
                connectionResponseHandler: completion
            ),
            sendFrom: .tonconnectLocal,
            appId: appId,
            initiatedBy: .tonconnectLocal,
            dappUrl: dapp.url.host,
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
            }
        )
    }

    private func signMessageAppName(wallet: Wallet, dapp: Dapp) -> String {
        let connectedApp: TonConnectApp?
        do {
            connectedApp = try keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore
                .connectedApps(forWallet: wallet).apps
                .first { $0.manifest.url.host == dapp.url.host && $0.connectionType == .bridge }
        } catch {
            Log.w("failed to load connected apps for sign message due to error: \(error)")
            connectedApp = nil
        }
        return [connectedApp?.manifest.name, dapp.name, dapp.url.host]
            .compactMap { $0 }
            .first { !$0.isEmpty } ?? dapp.url.absoluteString
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
            coreAssembly: coreAssembly,
            reason: .dappRequest
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
            dapp: app,
            url: url,
            analyticsSession: analyticsSession
        )

        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
        bottomSheetViewController.present(fromViewController: router.rootViewController.topPresentedViewController())
    }
}

private struct DappSignMessageResultHandler: SignRawControllerResultHandler {
    private let appRequest: TonConnect.SignMessageRequest
    private let connectionResponseHandler: (TonConnectAppsStore.SendResult) -> Void

    init(
        appRequest: TonConnect.SignMessageRequest,
        connectionResponseHandler: @escaping (TonConnectAppsStore.SendResult) -> Void
    ) {
        self.appRequest = appRequest
        self.connectionResponseHandler = connectionResponseHandler
    }

    func didConfirm(boc: String) {
        let signMessageResponse = TonConnect.SendResponse.success(
            .init(
                result: TonConnect.SignMessageResult(internalBoc: boc),
                id: appRequest.id
            )
        )
        let response: Data
        do {
            response = try JSONEncoder().encode(signMessageResponse)
        } catch {
            Log.e(
                "\(String(reflecting: Self.self)): failed to encode sign-message success response",
                extraInfo: [
                    "error": error.localizedDescription,
                    "requestId": appRequest.id,
                ]
            )
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
        let response: Data
        do {
            response = try JSONEncoder().encode(sendTransactionResponse)
        } catch {
            Log.e(
                "\(String(reflecting: Self.self)): failed to encode send-transaction success response",
                extraInfo: [
                    "error": error.localizedDescription,
                    "requestId": appRequest.id,
                ]
            )
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
        let response: Data
        do {
            response = try JSONEncoder().encode(signDataResponse)
        } catch {
            Log.e(
                "\(String(reflecting: Self.self)): failed to encode sign-data success response",
                extraInfo: [
                    "error": error.localizedDescription,
                    "requestId": appRequest.id,
                ]
            )
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
