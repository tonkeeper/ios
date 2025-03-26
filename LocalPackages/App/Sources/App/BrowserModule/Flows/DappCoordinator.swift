import UIKit
import TKCoordinator
import TKCore
import KeeperCore
import TKScreenKit
import TKUIKit
import TKLocalize
import SignRaw
import FirebasePerformance

enum DidRequireSignError: Swift.Error {
  case unknown
}

@MainActor
final class DappCoordinator: RouterCoordinator<ViewControllerRouter> {

  public var didHandleDeeplink: ((_ deeplink: Deeplink) -> Void)?

  private let dapp: Dapp
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly

  public var didRequestOpenBuySell: ((_ wallet: Wallet, _ isInternalPurchasing: Bool) -> Void)?

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
    let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet
    let messageHandler = DefaultDappMessageHandler()
    let module = DappAssembly.module(dapp: dapp, analyticsProvider: coreAssembly.analyticsProvider, deeplinkHandler: { deeplink in
      self.didHandleDeeplink?(deeplink)
    }, messageHandler: messageHandler, wallet: wallet)
    
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

    messageHandler.reconnect = { [weak self] dapp, completion in
      guard let self,
      let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else { return }

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
      try? self.keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore.disconnect(wallet: wallet, appUrl: dapp.url)
    }

    weak var moduleView = module.view
    messageHandler.sendTransaction = {
      [weak self] app, request, completion in
      guard let self, let moduleView, let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else { return }
      self.openSend(
        wallet: wallet,
        dapp: dapp,
        appRequest: request,
        fromViewController: moduleView,
        completion: completion
      )
    }
    
    messageHandler.signData = {
      [weak self] app, request, completion in
      guard let self, let moduleView, let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else { return }
      self.openSignData(
        wallet: wallet,
        dappUrl: dapp.url.host ?? "",
        appRequest: request,
        fromViewController: moduleView,
        router: router,
        completion: completion
      )
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
      let trace = Performance.startTrace(name: "perform_connect")
      do {
        let manifest = try await keeperCoreMainAssembly.tonConnectAssembly.tonConnectService().loadManifest(
          url: payload.manifestUrl
        )
        let parameters = TonConnectParameters(
          version: .v2,
          clientId: UUID().uuidString,
          requestPayload: payload
        )
        trace?.setValue(manifest.url.absoluteString, forAttribute: "manifest")
        await MainActor.run {
          ToastPresenter.hideToast()
          handleLoadedManifest(
            parameters: parameters,
            manifest: manifest,
            router: ViewControllerRouter(rootViewController: fromViewController),
            completion: completion
          )
        }
        trace?.setValue("success", forAttribute: "result")
      } catch {
        await MainActor.run {
          ToastPresenter.hideToast()
          completion(.error(.appManifestNotFound))
        }
        trace?.setValue("fail", forAttribute: "result")
      }
      trace?.stop()
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

  private func openSignData(wallet: Wallet,
                            dappUrl: String,
                            appRequest: TonConnect.SignDataRequest,
                            fromViewController: UIViewController,
                            router: ViewControllerRouter,
                            completion: @escaping (TonConnectAppsStore.SendResult) -> Void) {
    
    let signHandler = DappSignDataResultHandler(appRequest: appRequest, connectionResponseHandler: completion)
    
    guard let windowScene = fromViewController.view.window?.windowScene else {
      return
    }
    
    SignDataPresenter.presentSignData(
      windowScene: windowScene,
      windowLevel: .signData,
      wallet: wallet,
      dappUrl: dappUrl,
      request: appRequest,
      resultHandler: signHandler,
      didRequireSign: {[weak self] request, dappUrl, wallet, router in
        guard let self else {
          throw DidRequireSignError.unknown
        }
        return try await self.didRequireSign(
          request: request,
          dappUrl: dappUrl,
          wallet: wallet,
          coordinator: self,
          router: router
        )
      })
  }
  
  private func openSend(wallet: Wallet,
                        dapp: Dapp,
                        appRequest: TonConnect.SendTransactionRequest,
                        fromViewController: UIViewController,
                        completion: @escaping (TonConnectAppsStore.SendResult) -> Void) {
    guard let windowScene = fromViewController.view.window?.windowScene,
          let request = appRequest.params.first else {
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
      coreAssembly: coreAssembly,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      didRequireSign: { [weak self] transferData, wallet, coordinator, router in
        try await self?.didRequireSign(transferData: transferData,
                                       wallet: wallet,
                                       coordinator: coordinator,
                                       router: router)
      },
      didRequestReplanishWallet: { [weak self] wallet, isInternalPurchasing in
        self?.router.dismiss(animated: true) {
          self?.didRequestOpenBuySell?(wallet, isInternalPurchasing)
        }
      }
    )
  }

  @MainActor
  func didRequireSign(transferData: TransferData,
                      wallet: Wallet,
                      coordinator: Coordinator,
                      router: ViewControllerRouter) async throws -> SignedTransactions? {
    let coordinator = WalletTransferSignCoordinator(
      router: router,
      wallet: wallet,
      transferData: transferData,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly)

    let result = await coordinator.handleSign(parentCoordinator: coordinator)
  
    switch result {
    case .signed(let data):
      return data
    case .cancel:
      return nil
    case .failed(let error):
      throw error
    }
  }
  
  @MainActor
  func didRequireSign(request: TonConnect.SignDataRequest,
                      dappUrl: String,
                      wallet: Wallet,
                      coordinator: Coordinator,
                      router: ViewControllerRouter) async throws -> SignedDataResult? {
    
    let coordinator = SignDataSignCoordinator(router: router, wallet: wallet, dappUrl: dappUrl, request: request, keeperCoreMainAssembly: keeperCoreMainAssembly, coreAssembly: coreAssembly)

    let result = await coordinator.handleSign(parentCoordinator: coordinator)
      
    switch result {
    case .signed(let data):
      return data
    case .cancel:
      return nil
    case .failed(let error):
      throw error
    }
  }
}

private struct DappSignRawResultHandler: SignRawControllerResultHandler {
  private let appRequest: TonConnect.SendTransactionRequest
  private let connectionResponseHandler: (TonConnectAppsStore.SendResult) -> Void
  
  init(appRequest: TonConnect.SendTransactionRequest,
       connectionResponseHandler: @escaping (TonConnectAppsStore.SendResult) -> Void) {
    self.appRequest = appRequest
    self.connectionResponseHandler = connectionResponseHandler
  }
  
  func didConfirm(boc: String) {
    let sendTransactionResponse = TonConnect.SendResponse.success(
      .init(result: boc,
            id: appRequest.id)
    )
    guard let response = try? JSONEncoder().encode(sendTransactionResponse) else { return }
    connectionResponseHandler(.response(response))
  }
  
  func didFail(error: any Error) {
    connectionResponseHandler(.error(.unknownError))
  }
  
  func didCancel() {
    connectionResponseHandler(.error(.userDeclinedAction))
  }
}

private struct DappSignDataResultHandler: SignDataResultHandler {
  private let appRequest: TonConnect.SignDataRequest
  private let connectionResponseHandler: (TonConnectAppsStore.SendResult) -> Void
  
  init(appRequest: TonConnect.SignDataRequest,
       connectionResponseHandler: @escaping (TonConnectAppsStore.SendResult) -> Void) {
    self.appRequest = appRequest
    self.connectionResponseHandler = connectionResponseHandler
  }
  
  func didSign(signedData: SignedDataResult) {
    let signDataResponse = TonConnect.SendResponse.success(
      .init(result: signedData,
            id: appRequest.id)
    )
    guard let response = try? JSONEncoder().encode(signDataResponse) else { return }
    connectionResponseHandler(.response(response))
  }
  
  func didFail(error: any Error) {
    connectionResponseHandler(.error(.unknownError))
  }
  
  func didCancel() {
    connectionResponseHandler(.error(.userDeclinedAction))
  }
}
