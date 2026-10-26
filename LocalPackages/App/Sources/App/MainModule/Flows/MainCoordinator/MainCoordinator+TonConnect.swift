import AppUI
import KeeperCore
import SignRaw
import TKCore
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

extension MainCoordinator {
    func handleTonConnectRequest(
        _ appRequest: TonConnect.AppRequest,
        wallet: Wallet,
        app: TonConnectApp
    ) {
        switch appRequest {
        case let .sendTransaction(request):
            guard let signRawRequest = request.params.first else { return }

            let (sendFrom, appId, initiatedBy) = tonConnectRequestSource(app: app)

            var resultHandler = BridgeSignRawResultHandler(
                app: app,
                appRequest: request,
                tonConnectService: keeperCoreMainAssembly.tonConnectAssembly.tonConnectService()
            )
            resultHandler.didCancelHandler = { [weak self] in
                self?.showTonConnectDisconnectAppToast(app: app)
            }

            openSignRaw(wallet: wallet, mode: .sendTransaction, transferProvider: {
                .signRaw(signRawRequest, forceRelayer: false)
            }, resultHandler: resultHandler, sendFrom: sendFrom, appId: appId, initiatedBy: initiatedBy, dappUrl: app.manifest.host, redAnalyticsConfiguration: .init(
                flow: .tonConnect,
                operation: .confirmTransaction,
                attemptSource: sendFrom == .tonconnectLocal
                    ? .tonconnectLocal
                    : .tonconnectRemote,
                staticMetadata: [
                    .dappHost: app.manifest.host,
                    .connectionType: app.connectionType.rawValue,
                ]
            ))
        case let .signMessage(request):
            handleTonConnectSignMessageRequest(request, wallet: wallet, app: app)
        case let .signData(request):
            var resultHandler = BridgeSignDataResultHandler(
                app: app,
                appRequest: request,
                tonConnectService: keeperCoreMainAssembly.tonConnectAssembly.tonConnectService()
            )
            resultHandler.didCancelHandler = { [weak self] in
                self?.showTonConnectDisconnectAppToast(app: app)
            }

            openSignData(
                wallet: wallet,
                dappUrl: app.manifest.host,
                signRequest: request,
                resultHandler: resultHandler,
                redAnalyticsConfiguration: .init(
                    flow: .tonConnect,
                    operation: .confirmTransaction,
                    attemptSource: app.connectionType == .bridge
                        ? .tonconnectLocal
                        : .tonconnectRemote,
                    staticMetadata: [
                        .dappHost: app.manifest.host,
                        .connectionType: app.connectionType.rawValue,
                    ]
                )
            )
        case let .disconnect(request):
            let tonConnectService = keeperCoreMainAssembly.tonConnectAssembly.tonConnectService()
            Task {
                do {
                    try await tonConnectService.confirmDisconnectRequest(appRequest: request, app: app)
                } catch {
                    Log.w("failed to confirm Ton Connect disconnect request due to error: \(error)")
                }
            }
            try? keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore.disconnect(
                wallet: wallet,
                appClientId: app.clientId
            )
        }
    }

    private func handleTonConnectSignMessageRequest(
        _ request: TonConnect.SignMessageRequest,
        wallet: Wallet,
        app: TonConnectApp
    ) {
        let tonConnectService = keeperCoreMainAssembly.tonConnectAssembly.tonConnectService()
        let sendService = keeperCoreMainAssembly.servicesAssembly.sendService()
        let isSignMessageEnabled = keeperCoreMainAssembly.tonConnectAssembly.isSignMessageEnabled
        Task { @MainActor [weak self] in
            do throws(TonConnectSignMessageValidationError) {
                try await TonConnectSignMessageValidation.validate(
                    request.params,
                    wallet: wallet,
                    isSignMessageEnabled: isSignMessageEnabled,
                    sendService: sendService
                )
            } catch {
                ToastPresenter.showToast(configuration: .init(title: error.toastTitle))
                do {
                    try await tonConnectService.rejectSignMessageRequest(
                        appRequest: request,
                        app: app,
                        errorCode: error.errorCode,
                        message: error.message
                    )
                } catch {
                    Log.w("failed to reject Ton Connect sign message request due to error: \(error)")
                }
                return
            }
            self?.openTonConnectSignMessage(request, wallet: wallet, app: app, tonConnectService: tonConnectService)
        }
    }

    private func openTonConnectSignMessage(
        _ request: TonConnect.SignMessageRequest,
        wallet: Wallet,
        app: TonConnectApp,
        tonConnectService: TonConnectService
    ) {
        let (sendFrom, appId, initiatedBy) = tonConnectRequestSource(app: app)

        var resultHandler = BridgeSignMessageResultHandler(
            app: app,
            appRequest: request,
            tonConnectService: tonConnectService
        )
        resultHandler.didCancelHandler = { [weak self] in
            self?.showTonConnectDisconnectAppToast(app: app)
        }

        openSignRaw(
            wallet: wallet,
            mode: .signMessage(appName: app.manifest.name.isEmpty ? app.manifest.host : app.manifest.name),
            transferProvider: {
                .signRaw(request.params, forceRelayer: false)
            },
            resultHandler: resultHandler,
            sendFrom: sendFrom,
            appId: appId,
            initiatedBy: initiatedBy,
            dappUrl: app.manifest.host,
            redAnalyticsConfiguration: .init(
                flow: .tonConnect,
                operation: .confirmTransaction,
                attemptSource: sendFrom == .tonconnectLocal
                    ? .tonconnectLocal
                    : .tonconnectRemote,
                staticMetadata: [
                    .dappHost: app.manifest.host,
                    .connectionType: app.connectionType.rawValue,
                ]
            )
        )
    }

    private func tonConnectRequestSource(app: TonConnectApp) -> (SendOpen.From, String?, InitiatedBy) {
        switch app.connectionType {
        case .bridge:
            return (.tonconnectLocal, app.manifest.host, .tonconnectLocal)
        case .remote, .unknown:
            return (.tonconnectRemote, nil, .tonconnectRemote)
        }
    }

    func showTonConnectDisconnectAppToast(app: TonConnectApp) {
        guard let windowScene = self.router.rootViewController.windowScene else { return }
        let model = DisconnectDappToastModel(
            title: "\(TKLocales.Dapp.DisconnectToast.title) \"\(app.manifest.name)\"?",
            buttonTitle: TKLocales.Dapp.DisconnectToast.button,
            buttonAction: { [weak self] in
                guard let self else { return }
                // TODO: Extract this logic and from BrowserConnectedViewModel
                let tonConnectAppsStore = keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore
                keeperCoreMainAssembly.storesAssembly.connectedAppsStore(
                    tonConnectAppsStore: tonConnectAppsStore
                ).deleteApp(app)
            }
        )
        DisconnectDappToastPresenter.presentToast(
            model: model,
            windowScene: windowScene
        )
    }
}
