import DisconnectDappToast
import KeeperCore
import TKCore
import TKLocalize
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

            let sendFrom: SendOpen.From
            let appId: String?
            switch app.connectionType {
            case .bridge:
                sendFrom = .tonconnectLocal
                appId = app.manifest.host
            case .remote, .unknown:
                sendFrom = .tonconnectRemote
                appId = nil
            }

            var resultHandler = BridgeSignRawResultHandler(
                app: app,
                appRequest: request,
                tonConnectService: keeperCoreMainAssembly.tonConnectAssembly.tonConnectService()
            )
            resultHandler.didCancelHandler = { [weak self] in
                self?.showTonConnectDisconnectAppToast(app: app)
            }

            openSignRaw(wallet: wallet, transferProvider: {
                .signRaw(signRawRequest, forceRelayer: false)
            }, resultHandler: resultHandler, sendFrom: sendFrom, appId: appId, redAnalyticsConfiguration: .init(
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
                let pushTokenProvider = PushNotificationTokenProvider()
                let walletsStore = keeperCoreMainAssembly.storesAssembly.walletsStore
                let notificationsService = keeperCoreMainAssembly.servicesAssembly.notificationsService(
                    walletNotificationsStore: keeperCoreMainAssembly.storesAssembly.walletNotificationStore,
                    tonConnectAppsStore: tonConnectAppsStore
                )
                Task {
                    guard let token = await pushTokenProvider.getToken(),
                          let wallet = try? walletsStore.activeWallet else { return }
                    _ = try? await notificationsService.turnOffDappNotifications(
                        wallet: wallet,
                        manifest: app.manifest,
                        sessionId: app.clientId,
                        token: token
                    )
                }
            }
        )
        DisconnectDappToastPresenter.presentToast(
            model: model,
            windowScene: windowScene
        )
    }
}
