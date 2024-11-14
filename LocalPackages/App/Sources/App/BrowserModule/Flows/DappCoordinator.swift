import UIKit
import TKCoordinator
import TKCore
import KeeperCore
import TKScreenKit
import TKUIKit
import BigInt
import TKLocalize

@MainActor
final class DappCoordinator: RouterCoordinator<ViewControllerRouter> {

  public var didHandleDeeplink: ((_ deeplink: Deeplink) -> Void)?

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
    let module = DappAssembly.module(dapp: dapp, analyticsProvider: coreAssembly.analyticsProvider, deeplinkHandler: { deeplink in
      self.didHandleDeeplink?(deeplink)
    }, messageHandler: messageHandler)
    
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

    messageHandler.reconnect = { [weak self] dapp, completion in
      guard let self,
      let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else { return }

      let result = self.keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore.reconnectBridgeDapp(
        wallet: wallet,
        appUrl: dapp.url
      )
      completion(result)
    }

    messageHandler.disconnect = {
      [weak self] dapp in
      guard let self,
      let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else { return }
      try? self.keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore.disconnect(wallet: wallet, appUrl: dapp.url)
    }

    messageHandler.send = { [weak self] app, request, completion in
      guard let wallet = try? self?.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else {
        return
      }

      self?.openSend(wallet: wallet, dapp: dapp, appRequest: request, completion: completion)
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
        flow: .common,
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

  private func openSend(
    wallet: Wallet,
    dapp: Dapp,
    appRequest: TonConnect.AppRequest,
    completion: @escaping (TonConnectAppsStore.SendTransactionResult) -> Void) {
      ToastPresenter.showToast(configuration: .loading)

      guard let connectedApps = try? keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore.connectedApps(forWallet: wallet),
            let _ = connectedApps.apps.first(where: { $0.manifest.host == dapp.url.host })
      else {
        completion(.error(.unknownApp))
        return
      }

      Task {
        let confirmTransactionController = keeperCoreMainAssembly.confirmTransactionController(
          wallet: wallet,
          bocProvider: keeperCoreMainAssembly.tonConnectAssembly.tonConnectConfirmTransactionControllerBocProvider(
            signTransactionParams: appRequest.params
          )
        )

        let model = try await confirmTransactionController.createRequestModel()
        if let confirmModel = model.confirmModel {
          let (token, balance) = confirmModel.token
          var isConfirmFlowAvailable: Bool

          switch token {
          case .ton:
            isConfirmFlowAvailable = confirmModel.tonBalance >= confirmModel.requiredAmount
          case .jetton:
            let isFeeEnough = confirmModel.fee <= confirmModel.tonBalance
            isConfirmFlowAvailable = confirmModel.requiredAmount <= balance && isFeeEnough
          }

          guard isConfirmFlowAvailable else {
            startInsufficientFlow(wallet: wallet, model: confirmModel)
            completion(.error(.userDeclinedTransaction))
            return
          }
        }

        startSignTransactionConfirmationCoordinator(
          wallet: wallet,
          dapp: dapp,
          appRequest: appRequest,
          confirmModel: model,
          completion: completion
        )
      }
  }

  @MainActor
  private func startInsufficientFlow(wallet: Wallet, model: ConfirmTransactionController.ConfirmModel) {
    let viewController = InfoPopupBottomSheetViewController()
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)
    let configurationBuilder = InfoPopupBottomSheetConfigurationBuilder(
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )

    var buyButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
    buyButtonConfiguration.content = TKButton.Configuration.Content(
      title: .plainString(TKLocales.InsufficientFunds.buyTokenTitle(model.token.token.symbol))
    )
    buyButtonConfiguration.action = { [weak bottomSheetViewController, weak self] in
      bottomSheetViewController?.dismiss() {
        self?.router.dismiss(animated: true) { self?.didRequestOpenBuySell?() }
      }
    }
    let configuration = configurationBuilder.insufficientTokenConfiguration(
      walletLabel: wallet.metaData.label,
      tokenSymbol: model.token.token.symbol,
      tokenFractionalDigits: model.token.token.fractionDigits,
      required: BigUInt(integerLiteral: UInt64(model.requiredAmount)),
      available: BigUInt(integerLiteral: UInt64(model.token.availableBalance)),
      buttons: [buyButtonConfiguration]
    )
    viewController.configuration = configuration
    ToastPresenter.hideAll()
    bottomSheetViewController.present(fromViewController: router.rootViewController.topPresentedViewController())
  }

  @MainActor
  private func startSignTransactionConfirmationCoordinator(
    wallet: Wallet,
    dapp: Dapp,
    appRequest: TonConnect.AppRequest,
    confirmModel: ConfirmTransactionModel,
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
      confirmModel: confirmModel,
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
