import UIKit
import TKCoordinator
import TKCore
import KeeperCore
import TKScreenKit
import TKUIKit
import BigInt
import TKLocalize

final class DappCoordinator: RouterCoordinator<ViewControllerRouter> {

  private let dapp: Dapp
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly

  public var didRequestOpenBuySell: (() -> Void)?

  public init(
    router: ViewControllerRouter,
    dapp: Dapp,
    coreAssembly: TKCore.CoreAssembly,
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) {
    self.dapp = dapp
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly

    super.init(router: router)
  }

  override func start() {
    openDappModule(dapp)
  }

  private func openDappModule(_ dapp: Dapp) {
    let messageHandler = DefaultDappMessageHandler()
    let module = DappAssembly.module(dapp: dapp, analyticsProvider: coreAssembly.analyticsProvider, messageHandler: messageHandler)

    messageHandler.connect = { [weak self, weak moduleView = module.view] protocolVersion, payload, completion in
      guard let moduleView else {
        completion(.error(.unknownError))
        return
      }
      self?.performConnect(
        protocolVersion: protocolVersion,
        payload: payload,
        fromViewController: moduleView,
        completion: completion)
    }

    messageHandler.reconnect = {
      [weak self] dapp,
      completion in
      guard let self,
      let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.getActiveWallet() else { return }

      let result = self.keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore.reconnectBridgeDapp(
        wallet: wallet,
        appUrl: dapp.url
      )
      completion(result)
    }

    messageHandler.disconnect = {
      [weak self] dapp in
      guard let self,
      let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.getActiveWallet() else { return }
      try? self.keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore.disconnect(wallet: wallet, appUrl: dapp.url)
    }

    messageHandler.send = {
      [weak self] app, request, completion in
      guard let self else { return }
      self.openSend(dapp: dapp, appRequest: request, completion: completion)
    }

    module.view.modalPresentationStyle = .fullScreen
    router.rootViewController.topPresentedViewController().present(module.view, animated: true)
  }

  private func performConnect(protocolVersion: Int,
                              payload: TonConnectRequestPayload,
                              fromViewController: UIViewController,
                              completion: @escaping (TonConnectAppsStore.ConnectResult) -> Void) {
    ToastPresenter.hideAll()
    ToastPresenter.showToast(configuration: .loading)
    Task {
      do {
        let manifest = try await keeperCoreMainAssembly.tonConnectAssembly.tonConnectService().loadManifest(
          url: payload.manifestUrl
        )
        let parameters = TonConnectParameters(
          version: .v2,
          clientId: UUID().uuidString,
          requestPayload: payload
        )
        await MainActor.run {
          ToastPresenter.hideToast()
          handleLoadedManifest(
            parameters: parameters,
            manifest: manifest,
            router: ViewControllerRouter(rootViewController: fromViewController),
            completion: completion
          )
        }
      } catch {
        await MainActor.run {
          ToastPresenter.hideToast()
          completion(.error(.appManifestNotFound))
        }
      }
    }

    @Sendable
    func handleLoadedManifest(parameters: TonConnectParameters,
                              manifest: TonConnectManifest,
                              router: ViewControllerRouter,
                              completion: @escaping (TonConnectAppsStore.ConnectResult) -> Void) {
      let connector = BridgeTonConnectConnectCoordinatorConnector(
        tonConnectAppsStore: keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore) {
          completion($0)
        }
      let coordinator = TonConnectConnectCoordinator(
        router: router,
        connector: connector,
        parameters: parameters,
        manifest: manifest,
        showWalletPicker: false,
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )

      coordinator.didCancel = { [weak self, weak coordinator] in
        guard let coordinator else { return }
        self?.removeChild(coordinator)
      }

      coordinator.didConnect = { [weak self, weak coordinator] in
        guard let coordinator else { return }
        self?.removeChild(coordinator)
      }

      addChild(coordinator)
      coordinator.start()
    }
  }

  private func openSend(dapp: Dapp,
                        appRequest: TonConnect.AppRequest,
                        completion: @escaping (TonConnectAppsStore.SendTransactionResult) -> Void) {
    Task {
      guard let wallet = try? await self.keeperCoreMainAssembly.storesAssembly.walletsStore.getActiveWallet(),
            let connectedApps = try? self.keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore.connectedApps(forWallet: wallet),
            let _ = connectedApps.apps.first(where: { $0.manifest.host == dapp.url.host }) else {

        completion(.error(.unknownApp))
        return
      }

      let confirmTransactionController = keeperCoreMainAssembly.confirmTransactionController(
        wallet: wallet,
        bocProvider: keeperCoreMainAssembly.tonConnectAssembly.tonConnectConfirmTransactionControllerBocProvider(
          signTransactionParams: appRequest.params
        )
      )

      let transactionAvailabilityModel = try await confirmTransactionController.confirmTransactionAvailability(param: appRequest.params.first)
      if let transactionAvailabilityModel,
          transactionAvailabilityModel.requiredAmount > transactionAvailabilityModel.availableAmount {
        
        ToastPresenter.hideAll()
        await startInsufficientFlow(model: transactionAvailabilityModel)
        completion(.error(.userDeclinedTransaction))
      } else {
        await startSignTransactionConfirmationCoordinator(
          wallet: wallet,
          dapp: dapp,
          appRequest: appRequest,
          confirmTransactionController: confirmTransactionController,
          completion: completion
        )
      }
    }
  }

  @MainActor
  private func startInsufficientFlow(model: ConfirmTransactionController.ConfirmTransactionAvailabilityModel) {
    let viewController = InsufficientFundsViewController()
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)
    let configurationBuilder = InsufficientFundsViewControllerConfigurationBuilder(
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )

    var buyButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
    buyButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString(TKLocales.InsufficientFunds.buyTokenTitle(model.token.symbol)))
    buyButtonConfiguration.action = { [weak bottomSheetViewController, weak self] in
      bottomSheetViewController?.dismiss() {
        self?.router.dismiss(animated: true) { self?.didRequestOpenBuySell?() }
      }
    }
    let configuration = configurationBuilder.insufficientTokenConfiguration(
      tokenSymbol: model.token.symbol,
      tokenFractionalDigits: model.token.fractionDigits,
      required: BigUInt(integerLiteral: model.requiredAmount),
      available: BigUInt(integerLiteral: model.availableAmount),
      buttons: [buyButtonConfiguration]
    )
    viewController.configuration = configuration
    bottomSheetViewController.present(fromViewController: router.rootViewController.topPresentedViewController())
  }

  @MainActor
  private func startSignTransactionConfirmationCoordinator(
    wallet: Wallet,
    dapp: Dapp,
    appRequest: TonConnect.AppRequest,
    confirmTransactionController: ConfirmTransactionController,
    completion: @escaping (TonConnectAppsStore.SendTransactionResult) -> Void
  ) {
    guard let windowScene = UIApplication.keyWindowScene else { return }
    let window = TKWindow(windowScene: windowScene)

    let coordinator = SignTransactionConfirmationCoordinator(
      router: WindowRouter(window: window),
      wallet: wallet,
      confirmator: BridgeTonConnectSignTransactionConfirmationCoordinatorConfirmator(
        appRequest: appRequest,
        sendService: keeperCoreMainAssembly.servicesAssembly.sendService(),
        tonConnectService: keeperCoreMainAssembly.tonConnectAssembly.tonConnectService(),
        connectionResponseHandler: completion),
      confirmTransactionController: confirmTransactionController,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )

    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }

    coordinator.didConfirm = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }

    addChild(coordinator)
    coordinator.start()
  }
}
