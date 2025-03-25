import UIKit
import KeeperCore
import TKCore
import TKLocalize
import DisconnectDappToast

extension MainCoordinator {
  func handleTonConnectRequest(_ appRequest: TonConnect.AppRequest,
                               wallet: Wallet,
                               app: TonConnectApp) {
    switch appRequest {
    case .sendTransaction(let request):
      guard let signRawRequest = request.params.first else { return }
      
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
      }, resultHandler: resultHandler)
    case .signData(let request):
      var resultHandler = BridgeSignDataResultHandler(
        app: app,
        appRequest: request,
        tonConnectService: keeperCoreMainAssembly.tonConnectAssembly.tonConnectService())
      resultHandler.didCancelHandler = { [weak self] in
        self?.showTonConnectDisconnectAppToast(app: app)
      }
      
      openSignData(
        wallet: wallet,
        dappUrl: app.manifest.host,
        signRequest: request,
        resultHandler: resultHandler
      )
    }
  }
  
  private func showTonConnectDisconnectAppToast(app: TonConnectApp) {
    guard let windowScene = self.router.rootViewController.view.window?.windowScene else { return }
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
            token: token)
        }
      }
    )
    DisconnectDappToastPresenter.presentToast(
      model: model,
      windowScene: windowScene
    )
  }
}
