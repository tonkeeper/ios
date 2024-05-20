import UIKit
import KeeperCore
import TKCoordinator
import TKUIKit
import TKCore

protocol TonConnectConfirmationCoordinatorConfirmator {
  func confirm(appRequest: TonConnect.AppRequest, app: TonConnectApp, wallet: Wallet) async throws
  func cancel(appRequest: TonConnect.AppRequest, app: TonConnectApp, wallet: Wallet) async
}

struct DefaultTonConnectConfirmationCoordinatorConfirmator: TonConnectConfirmationCoordinatorConfirmator {
  private let sendService: SendService
  private let tonConnectService: TonConnectService
  
  init(sendService: SendService, tonConnectService: TonConnectService) {
    self.sendService = sendService
    self.tonConnectService = tonConnectService
  }
  
  func confirm(appRequest: TonConnect.AppRequest, app: TonConnectApp, wallet: Wallet) async throws {
    guard let parameters = appRequest.params.first else { return }
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)

    let boc = try await tonConnectService.createConfirmTransactionBoc(
      wallet: wallet,
      seqno: seqno,
      timeout: timeout,
      parameters: parameters
    )
    
    try await sendService.sendTransaction(boc: boc, wallet: wallet)
    try await tonConnectService.confirmRequest(boc: boc, appRequest: appRequest, app: app)
  }
  
  func cancel(appRequest: TonConnect.AppRequest, app: TonConnectApp, wallet: Wallet) async {
    try? await tonConnectService.cancelRequest(appRequest: appRequest, app: app)
  }
}

struct BridgeTonConnectConfirmationCoordinatorConfirmator: TonConnectConfirmationCoordinatorConfirmator {
  private let sendService: SendService
  private let tonConnectService: TonConnectService
  private let connectionResponseHandler: (TonConnectAppsStore.SendTransactionResult) -> Void
  
  init(sendService: SendService,
       tonConnectService: TonConnectService,
       connectionResponseHandler: @escaping (TonConnectAppsStore.SendTransactionResult) -> Void) {
    self.sendService = sendService
    self.tonConnectService = tonConnectService
    self.connectionResponseHandler = connectionResponseHandler
  }
  
  func confirm(appRequest: TonConnect.AppRequest, app: TonConnectApp, wallet: Wallet) async throws {
    guard let parameters = appRequest.params.first else { return }
    do {
      let seqno = try await sendService.loadSeqno(wallet: wallet)
      let timeout = await sendService.getTimeoutSafely(wallet: wallet)
      let boc = try await tonConnectService.createConfirmTransactionBoc(
        wallet: wallet,
        seqno: seqno,
        timeout: timeout,
        parameters: parameters
      )
      
      try await sendService.sendTransaction(boc: boc, wallet: wallet)
      let sendTransactionResponse = TonConnect.SendTransactionResponse.success(
        .init(result: boc,
              id: appRequest.id)
      )
      let response = try JSONEncoder().encode(sendTransactionResponse)
      connectionResponseHandler(.response(response))
    } catch {
      connectionResponseHandler(.error(.unknownError))
    }
  }
  
  func cancel(appRequest: TonConnect.AppRequest, app: TonConnectApp, wallet: Wallet) async {
    connectionResponseHandler(.error(.userDeclinedTransaction))
  }
}

final class TonConnectConfirmationCoordinator: RouterCoordinator<WindowRouter> {
  
  var didCancel: (() -> Void)?
  var didConfirm: (() -> Void)?
  
  private let wallet: Wallet
  private let appRequest: TonConnect.AppRequest
  private let app: TonConnectApp
  private let confirmator: TonConnectConfirmationCoordinatorConfirmator
  private let tonConnectConfirmationController: TonConnectConfirmationController
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(router: WindowRouter,
       wallet: Wallet,
       appRequest: TonConnect.AppRequest,
       app: TonConnectApp,
       confirmator: TonConnectConfirmationCoordinatorConfirmator,
       tonConnectConfirmationController: TonConnectConfirmationController,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly) {
    self.wallet = wallet
    self.appRequest = appRequest
    self.app = app
    self.confirmator = confirmator
    self.tonConnectConfirmationController = tonConnectConfirmationController
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  override func start() {
    ToastPresenter.showToast(configuration: .loading)
    Task {
      do {
        let model = try await tonConnectConfirmationController.createRequestModel()
        await MainActor.run {
          ToastPresenter.hideAll()
          openConfirmation(model: model)
        }
      } catch {
        await MainActor.run {
          ToastPresenter.hideAll()
        }
      }
    }
  }
}

private extension TonConnectConfirmationCoordinator {
  func openConfirmation(model: TonConnectConfirmationController.Model) {
    let rootViewController = UIViewController()
    router.window.rootViewController = rootViewController
    router.window.makeKeyAndVisible()
    
    let keyWindow = UIApplication.keyWindow
    
    let module = TonConnectConfirmationAssembly.module(
      model: model,
      historyEventMapper: HistoryEventMapper(accountEventActionContentProvider: TonConnectConfirmationAccountEventActionContentProvider())
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    bottomSheetViewController.didClose = { [weak self, weak tonConnectConfirmationController] isInteractivly in
      guard isInteractivly else { return }
      guard let tonConnectConfirmationController else { return }
      keyWindow?.makeKeyAndVisible()
      self?.didCancel?()
      Task {
        await tonConnectConfirmationController.cancel()
      }
    }
    
    module.output.didTapCancelButton = { [weak self, weak bottomSheetViewController] in
      guard let self else { return }
      Task {
        await self.confirmator.cancel(appRequest: self.appRequest, app: self.app, wallet: self.wallet)
      }
      bottomSheetViewController?.dismiss(completion: { [weak self] in
        self?.didCancel?()
      })
    }
    
    module.output.didTapConfirmButton = { [weak self, weak bottomSheetViewController] in
      guard let bottomSheetViewController, let self else { return false }
      let isConfirmed = await self.openPasscodeConfirmation(fromViewController: bottomSheetViewController)
      guard isConfirmed else { return false }
      do {
        try await self.confirmator.confirm(appRequest: self.appRequest, app: self.app, wallet: self.wallet)
        return true
      } catch {
        return false
      }
    }
    
    module.output.didConfirm = { [weak self, weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss(completion: { [weak self] in
        self?.didConfirm?()
      })
    }
    
    bottomSheetViewController.present(fromViewController: rootViewController)
  }
  
  func openPasscodeConfirmation(fromViewController: UIViewController) async -> Bool {
    return await Task<Bool, Never> { @MainActor in
      return await withCheckedContinuation { [weak self, keeperCoreMainAssembly] (continuation: CheckedContinuation<Bool, Never>) in
        guard let self = self else { return }
        let coordinator = PasscodeModule(
          dependencies: PasscodeModule.Dependencies(
            passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
          )
        ).passcodeConfirmationCoordinator()
        
        coordinator.didCancel = { [weak self, weak coordinator] in
          continuation.resume(returning: false)
          coordinator?.router.dismiss(completion: {
            guard let coordinator else { return }
            self?.removeChild(coordinator)
          })
        }
        
        coordinator.didConfirm = { [weak self, weak coordinator] in
          continuation.resume(returning: true)
          coordinator?.router.dismiss(completion: {
            guard let coordinator else { return }
            self?.removeChild(coordinator)
          })
        }
        
        self.addChild(coordinator)
        coordinator.start()
        
        fromViewController.present(coordinator.router.rootViewController, animated: true)
      }
    }.value
  }
}
